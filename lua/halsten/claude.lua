-- Ask Claude for a chunk of code and drop it in at the cursor, without ever
-- blocking the editor. The request runs as a detached process; you keep typing
-- while a spinner sits in the buffer where the answer will land.
--
-- The insertion point is an extmark, not a (row, col) pair, so the answer lands
-- in the right place even if you edited above it -- or in another buffer
-- entirely -- while the request was in flight.

local M = {}

local ns = vim.api.nvim_create_namespace("halsten_claude")

-- The marker written into the context at the cursor position, so the model
-- knows which hole it is filling rather than guessing from the prompt alone.
-- Deliberately not valid syntax in any language we use, so it can't be confused
-- with real code, and rare enough that stripping it back out is safe.
local MARK = "«HERE»"

local opts = {
  -- Inline fill is latency-bound, not intelligence-bound -- sonnet answers a
  -- "write this function body" prompt in ~3s where opus takes noticeably
  -- longer. Swap to "opus" here if you'd rather wait for the better answer.
  model = "sonnet",

  -- Hard ceiling on a request. vim.system kills the process at this point and
  -- the callback fires with a non-zero code, so the spinner always gets
  -- cleaned up even if the CLI hangs.
  timeout = 120000,

  frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
  frame_ms = 80,

  -- Lines either side of the cursor to send when scope is "function" but no
  -- enclosing function can be found (no parser for the filetype, an unknown
  -- grammar, or the cursor is at the top level). A window is the honest
  -- fallback -- silently promoting to whole-buffer would send far more than
  -- was asked for on a big file.
  fallback_context = 60,
}

-- Node types that count as "the function around the cursor". Listed explicitly
-- rather than pattern-matched on the name: a `function_call` in Lua would match
-- any sensible pattern and hand back the range of a call's arguments, which is
-- not the enclosing function at all.
local func_nodes = {
  function_declaration = true, -- go, lua, js
  function_definition = true,  -- lua, python, c, c++
  function_item = true,        -- rust
  method_declaration = true,   -- go, java
  method_definition = true,    -- js, ts
  method_elem = true,          -- go interface methods
  func_literal = true,         -- go closures
  arrow_function = true,       -- js, ts
  function_expression = true,  -- js
  local_function = true,       -- lua
}

-- Every in-flight request, so ClaudeCancel can reach them. Keyed by extmark id,
-- which is unique per buffer -- concurrent requests in *different* buffers can
-- share an id, hence the buffer in the value rather than in the key.
local running = {}

-- 0-indexed, inclusive line range of the function containing the cursor.
local function enclosing_function(buf, row, col)
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = buf, pos = { row - 1, col } })
  if not ok then
    return nil
  end

  while node do
    if func_nodes[node:type()] then
      local first, _, last, _ = node:range()
      return first, last
    end
    node = node:parent()
  end
end

-- The slice of buffer we hand the model, with MARK inserted at the cursor.
local function build_context(buf, row, col, scope)
  local count = vim.api.nvim_buf_line_count(buf)
  local first, last

  if scope == "buffer" then
    first, last = 0, count - 1
  else
    first, last = enclosing_function(buf, row, col)
    if not first then
      first = math.max(0, row - 1 - opts.fallback_context)
      last = math.min(count - 1, row - 1 + opts.fallback_context)
    end
  end

  local lines = vim.api.nvim_buf_get_lines(buf, first, last + 1, false)

  -- `row` is 1-based and `first` 0-based, so the cursor's line sits at index
  -- (row - 1) - first in 0-based terms, one past that in this 1-based table.
  local i = row - first
  if lines[i] then
    lines[i] = lines[i]:sub(1, col) .. MARK .. lines[i]:sub(col + 1)
  end

  return table.concat(lines, "\n")
end

-- Where the text actually goes, what to indent its later lines with, and what
-- the first line needs in front of it (nothing, unless we're inserting into a
-- line with no indent of its own to sit after).
--
-- Normal mode puts the cursor *on* a character, never past the last one, so on
-- the `\t` line of an empty function body the cursor reports column 0 -- in
-- front of the indent. Inserting there would push the indent to the end of the
-- generated code. Whenever the whole line is blank, the answer belongs at the
-- end of it and that whitespace is the indent.
local function insert_point(buf, row, col)
  local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""

  if line:match("^[ \t]*$") then
    if line ~= "" then
      return #line, line, ""
    end

    -- Nothing on the line at all, so there is no indent to copy. Take the last
    -- line that had one, and step in once more if it opened a block -- what
    -- 'autoindent' would have given had the line been typed rather than left
    -- empty.
    local prev = vim.fn.prevnonblank(row - 1)
    local above = prev > 0 and vim.api.nvim_buf_get_lines(buf, prev - 1, prev, false)[1] or ""
    local step = vim.bo[buf].expandtab and (" "):rep(vim.fn.shiftwidth()) or "\t"
    local indent = above:match("^[ \t]*") .. (above:match("[%{%(%[:]%s*$") and step or "")
    -- Column 0 of an empty line: there is no existing indent for the first line
    -- to land after, so it carries its own.
    return 0, indent, indent
  end

  -- Mid-line: insert exactly where the cursor is. Later lines follow the
  -- cursor's own prefix when that is all whitespace, otherwise the line's
  -- indent -- the two only differ when the cursor sits inside real code.
  local before = line:sub(1, col)
  return col, before:match("^[ \t]*$") and before or line:match("^[ \t]*"), ""
end

-- Models still emit fences now and then despite being told not to. Strip a
-- leading ```lang / trailing ``` pair, and any marker echoed back at us.
--
-- Then flatten the indentation, so the caller can re-indent to wherever it is
-- inserting. What comes back varies: the model writes the first line as a
-- continuation of the marker (flush) but the rest at the indentation they'd
-- have in the file -- except when it writes the whole answer flush left, which
-- it also does. Neither is wrong from its side; both need normalising.
--
-- The first line always lands at a column that already carries the indent, so
-- it is stripped bare. The rest are dedented by the longest whitespace prefix
-- they all share, which is the body indent in the first case and nothing in the
-- second -- leaving relative indentation either way.
local function clean(out)
  local lines = vim.split(vim.trim(out), "\n")

  if lines[1] and lines[1]:match("^%s*```") then
    table.remove(lines, 1)
    if lines[#lines] and lines[#lines]:match("^%s*```%s*$") then
      table.remove(lines)
    end
  end

  local common
  for n, line in ipairs(lines) do
    line = line:gsub(MARK, "")
    lines[n] = line

    if n > 1 and line:match("%S") then
      local ws = line:match("^[ \t]*")
      if not common then
        common = ws
      else
        -- Compared byte by byte rather than by width: a tab and four spaces
        -- may look the same but aren't interchangeable as a prefix.
        local i = 1
        while i <= #common and i <= #ws and common:sub(i, i) == ws:sub(i, i) do
          i = i + 1
        end
        common = common:sub(1, i - 1)
      end
    end
  end

  lines[1] = lines[1]:gsub("^[ \t]*", "")

  if common and common ~= "" then
    for n = 2, #lines do
      lines[n] = lines[n]:sub(#common + 1)
    end
  end

  return lines
end

local function stop(id)
  local job = running[id]
  if not job then
    return
  end
  running[id] = nil

  if job.timer then
    job.timer:stop()
    job.timer:close()
  end

  if vim.api.nvim_buf_is_valid(job.buf) then
    vim.api.nvim_buf_del_extmark(job.buf, ns, id)
  end
end

-- Redraw the spinner at wherever the extmark has drifted to. Returns false once
-- the mark is gone (buffer closed, text deleted out from under it), which is
-- the signal to give up on this request.
local function tick(id, frame, started)
  local job = running[id]
  if not job or not vim.api.nvim_buf_is_valid(job.buf) then
    return false
  end

  local pos = vim.api.nvim_buf_get_extmark_by_id(job.buf, ns, id, {})
  if not pos[1] then
    return false
  end

  local text = ("%s Claude %ds "):format(opts.frames[frame], os.time() - started)

  -- "inline" puts the spinner exactly at the insertion column, pushing any real
  -- text on that line to the right for the duration -- which is what makes it
  -- read as "work happening *here*" rather than a note at the end of the line.
  -- Reusing `id` moves the same extmark instead of stacking new ones.
  vim.api.nvim_buf_set_extmark(job.buf, ns, pos[1], pos[2], {
    id = id,
    virt_text = { { text, "HalstenClaudeSpinner" } },
    virt_text_pos = "inline",
  })

  return true
end

--- Prompt for an instruction, send it with context, insert the answer at the cursor.
--- @param scope "function"|"buffer" how much of the buffer to send as context
function M.here(scope)
  if vim.fn.executable("claude") ~= 1 then
    vim.notify("claude: not on PATH", vim.log.levels.ERROR)
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local ft = vim.bo[buf].filetype

  -- Grab the context now, at the moment of asking -- not in the callback, where
  -- the buffer may have moved on.
  local ctx = build_context(buf, row, col, scope)

  -- Only lines 2..n get the indent -- the first one lands at the insertion
  -- column, which is already past it.
  local at, indent, lead = insert_point(buf, row, col)

  vim.ui.input({ prompt = ("Claude (%s): "):format(scope) }, function(prompt)
    if not prompt or vim.trim(prompt) == "" then
      return
    end

    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end

    -- A link, not a colour: `:colorscheme` runs `hi clear`, so this is set on
    -- every request rather than once at load, where a later theme switch would
    -- silently wipe it.
    vim.api.nvim_set_hl(0, "HalstenClaudeSpinner", { link = "Special" })

    local mark = vim.api.nvim_buf_set_extmark(buf, ns, row - 1, at, {})
    local started = os.time()

    local sys = table.concat({
      ("Output ONLY raw %s code."):format(ft ~= "" and ft or "plain text"),
      "No markdown fences, no prose, no explanation, no commentary.",
      ("Your output is inserted verbatim where the %s marker sits in the context on stdin."):format(MARK),
      "Do not repeat any code that already surrounds the marker -- no signature, no closing brace.",
      -- Asking for real indentation rather than flush-left output: it is what
      -- the model does anyway half the time, and `clean` flattens whichever it
      -- picks. Asking for flush-left produced a mix of the two in one answer.
      "Indent the code as it should appear in the file.",
    }, " ")

    local job = vim.system({
      "claude",
      "-p",
      prompt,
      "--model",
      opts.model,
      "--append-system-prompt",
      sys,
      -- Nothing personal in a code-completion request: no CLAUDE.md, no hooks,
      -- no skills, no MCP servers, no session written to disk. Keeps the answer
      -- to the prompt and cuts the startup the CLI would otherwise do.
      "--safe-mode",
      "--no-session-persistence",
      -- We already handed over the context it needs. Left enabled, the model
      -- would spend seconds reading files to confirm what is already on stdin.
      "--disallowed-tools",
      "Bash,Edit,Write,Read,Glob,Grep,WebFetch,WebSearch,Task",
    }, {
      stdin = ctx,
      text = true,
      timeout = opts.timeout,
      -- Run where the file lives, so the CLI resolves the right project.
      cwd = vim.fn.isdirectory(vim.fn.expand("%:p:h")) == 1 and vim.fn.expand("%:p:h") or vim.fn.getcwd(),
    }, function(res)
      vim.schedule(function()
        if not running[mark] then
          return -- cancelled while in flight
        end

        local buf_valid = vim.api.nvim_buf_is_valid(buf)
        local pos = buf_valid and vim.api.nvim_buf_get_extmark_by_id(buf, ns, mark, {})
        stop(mark)

        if res.code ~= 0 then
          local err = vim.trim(res.stderr or "")
          vim.notify("claude: " .. (err ~= "" and err or "exited " .. res.code), vim.log.levels.ERROR)
          return
        end

        if not pos or not pos[1] then
          vim.notify("claude: insertion point is gone, answer dropped", vim.log.levels.WARN)
          return
        end

        local lines = clean(res.stdout or "")
        if #lines == 0 or (#lines == 1 and lines[1] == "") then
          vim.notify("claude: empty answer", vim.log.levels.WARN)
          return
        end

        lines[1] = lead .. lines[1]

        -- Blank lines are left alone rather than filled with the indent, so the
        -- insert doesn't leave trailing whitespace behind.
        for n = 2, #lines do
          if lines[n] ~= "" then
            lines[n] = indent .. lines[n]
          end
        end

        vim.api.nvim_buf_set_text(buf, pos[1], pos[2], pos[1], pos[2], lines)
        vim.notify(("Claude ✓ %d lines in %ds"):format(#lines, os.time() - started))
      end)
    end)

    local timer = vim.uv.new_timer()
    running[mark] = { buf = buf, timer = timer, job = job }

    local frame = 1
    timer:start(0, opts.frame_ms, function()
      frame = frame % #opts.frames + 1
      vim.schedule(function()
        -- The buffer went away or the mark was deleted: nothing left to insert
        -- into, so stop burning cycles and kill the request.
        if not tick(mark, frame, started) then
          local j = running[mark]
          stop(mark)
          if j then
            j.job:kill("sigterm")
          end
        end
      end)
    end)
  end)
end

--- Kill every in-flight request and clear its spinner.
function M.cancel()
  local n = 0
  for id, job in pairs(running) do
    job.job:kill("sigterm")
    stop(id)
    n = n + 1
  end
  vim.notify(n > 0 and ("Claude: cancelled %d request(s)"):format(n) or "Claude: nothing running")
end

vim.api.nvim_create_user_command("ClaudeCancel", M.cancel, { desc = "Cancel in-flight Claude requests" })

return M
