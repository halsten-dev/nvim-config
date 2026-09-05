-- Ask Codex for a chunk of code and drop it in at the cursor, without ever
-- blocking the editor. The request runs as a background process; you keep typing
-- while a spinner sits in the buffer where the answer will land.
--
-- The insertion point is an extmark, not a (row, col) pair, so the answer lands
-- in the right place even if you edited above it -- or in another buffer
-- entirely -- while the request was in flight.

local M = {}

local ns = vim.api.nvim_create_namespace("halsten_codex")

-- The marker written into the context at the cursor position, so the model
-- knows which hole it is filling rather than guessing from the prompt alone.
-- Deliberately not valid syntax in any language we use, so it can't be confused
-- with real code, and rare enough that stripping it back out is safe.
local MARK = "«HERE»"

local opts = {
  -- nil uses the CLI default model. Set a Codex model name here to override it.
  -- Personal CLI configuration is skipped for these isolated fill requests.
  model = nil,

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

-- Every in-flight request, so CodexCancel can reach them. Keys include the
-- buffer and extmark id: extmark ids alone are only unique within a buffer.
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

  if #lines == 0 then
    return lines
  end

  lines[1] = lines[1]:gsub("^[ \t]*", "")

  if common and common ~= "" then
    for n = 2, #lines do
      lines[n] = lines[n]:sub(#common + 1)
    end
  end

  return lines
end

-- Usage comes from the completed turn, not an estimate of the inserted code.
-- Cached input and reasoning output are subsets of input/output respectively;
-- adding those again would count the same tokens twice.
local function token_usage(out)
  local usage
  for line in out:gmatch("[^\r\n]+") do
    local ok, event = pcall(vim.json.decode, line)
    if ok and type(event) == "table" and event.type == "turn.completed" then
      usage = event.usage
    end
  end

  if type(usage) ~= "table"
    or type(usage.input_tokens) ~= "number" or usage.input_tokens < 0
    or type(usage.output_tokens) ~= "number" or usage.output_tokens < 0 then
    return "unavailable"
  end

  local detail = ("%d input, %d output"):format(usage.input_tokens, usage.output_tokens)
  if type(usage.cached_input_tokens) == "number" and usage.cached_input_tokens >= 0 then
    detail = detail .. (", %d cached input"):format(usage.cached_input_tokens)
  end
  return ("%d (%s)"):format(usage.input_tokens + usage.output_tokens, detail)
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
    vim.api.nvim_buf_del_extmark(job.buf, ns, job.mark)
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

  local pos = vim.api.nvim_buf_get_extmark_by_id(job.buf, ns, job.mark, {})
  if not pos[1] then
    return false
  end

  local text = ("%s Codex %ds "):format(opts.frames[frame], os.time() - started)

  -- "inline" puts the spinner exactly at the insertion column, pushing any real
  -- text on that line to the right for the duration -- which is what makes it
  -- read as "work happening *here*" rather than a note at the end of the line.
  -- Reusing `id` moves the same extmark instead of stacking new ones.
  vim.api.nvim_buf_set_extmark(job.buf, ns, pos[1], pos[2], {
    id = job.mark,
    virt_text = { { text, "HalstenCodexSpinner" } },
    virt_text_pos = "inline",
  })

  return true
end

--- Prompt for an instruction, send it with context, insert the answer at the cursor.
--- @param scope "function"|"buffer" how much of the buffer to send as context
function M.here(scope)
  if vim.fn.executable("codex") ~= 1 then
    vim.notify("codex: not on PATH", vim.log.levels.ERROR)
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

  vim.ui.input({ prompt = ("Codex (%s): "):format(scope) }, function(prompt)
    if not prompt or vim.trim(prompt) == "" then
      return
    end

    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end

    -- A link, not a colour: `:colorscheme` runs `hi clear`, so this is set on
    -- every request rather than once at load, where a later theme switch would
    -- silently wipe it.
    vim.api.nvim_set_hl(0, "HalstenCodexSpinner", { link = "Special" })

    local mark = vim.api.nvim_buf_set_extmark(buf, ns, row - 1, at, {})
    local id = buf .. ":" .. mark
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
      "Use only the supplied context. Do not call tools or edit files.",
    }, " ")

    -- An empty working directory avoids project configuration, skills and MCP
    -- discovery. Authentication still comes from the normal Codex login.
    local cwd = vim.fn.tempname()
    local made, err = pcall(vim.fn.mkdir, cwd, "p", 448)
    if not made or err ~= 1 then
      vim.api.nvim_buf_del_extmark(buf, ns, mark)
      vim.notify("codex: " .. tostring(err), vim.log.levels.ERROR)
      return
    end

    local cmd = {
      "codex", "exec",
      "--json",
      "--output-last-message", cwd .. "/answer",
      "--ephemeral",
      "--ignore-user-config",
      "--skip-git-repo-check",
      "--sandbox", "read-only",
      "--color", "never",
      "-c", "project_doc_max_bytes=0",
      "-c", 'web_search="disabled"',
      "-c", "features={shell_tool=false,plugins=false,apps=false,hooks=false,"
        .. "multi_agent=false,browser_use=false,computer_use=false,image_generation=false,skill_search=false}",
    }
    if opts.model then
      vim.list_extend(cmd, { "--model", opts.model })
    end
    -- Send all text on stdin so long prompts remain safe and leading dashes
    -- cannot be parsed as CLI options. JSON events carry usage on stdout;
    -- the answer file contains only the final code to insert.
    cmd[#cmd + 1] = "-"

    local ok, job = pcall(vim.system, cmd, {
      stdin = sys .. "\n\nInstruction:\n" .. prompt .. "\n\nContext:\n" .. ctx,
      text = true,
      timeout = opts.timeout,
      cwd = cwd,
    }, function(res)
      vim.schedule(function()
        if not running[id] then
          vim.fn.delete(cwd, "rf")
          return -- cancelled while in flight
        end

        local answer
        if res.code == 0 then
          local read_ok, contents = pcall(vim.fn.readfile, cwd .. "/answer")
          if read_ok then
            answer = table.concat(contents, "\n")
          end
        end
        vim.fn.delete(cwd, "rf")

        local buf_valid = vim.api.nvim_buf_is_valid(buf)
        local pos = buf_valid and vim.api.nvim_buf_get_extmark_by_id(buf, ns, mark, {})
        stop(id)

        if res.code ~= 0 then
          local err = vim.trim(res.stderr or "")
          vim.notify("codex: " .. (err ~= "" and err or "exited " .. res.code), vim.log.levels.ERROR)
          return
        end

        if not pos or not pos[1] then
          vim.notify("codex: insertion point is gone, answer dropped", vim.log.levels.WARN)
          return
        end

        if not answer then
          vim.notify("codex: could not read the final answer", vim.log.levels.ERROR)
          return
        end

        local lines = clean(answer)
        if #lines == 0 or (#lines == 1 and lines[1] == "") then
          vim.notify("codex: empty answer", vim.log.levels.WARN)
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
        vim.notify(("Codex ✓ %d lines in %ds - Tokens used: %s")
          :format(#lines, os.time() - started, token_usage(res.stdout or "")))
      end)
    end)

    if not ok then
      vim.fn.delete(cwd, "rf")
      vim.api.nvim_buf_del_extmark(buf, ns, mark)
      vim.notify("codex: " .. tostring(job), vim.log.levels.ERROR)
      return
    end

    local timer = vim.uv.new_timer()
    running[id] = { buf = buf, mark = mark, timer = timer, job = job }

    local frame = 1
    timer:start(0, opts.frame_ms, function()
      frame = frame % #opts.frames + 1
      vim.schedule(function()
        -- The buffer went away or the mark was deleted: nothing left to insert
        -- into, so stop burning cycles and kill the request.
        if not tick(id, frame, started) then
          local j = running[id]
          stop(id)
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
  vim.notify(n > 0 and ("Codex: cancelled %d request(s)"):format(n) or "Codex: nothing running")
end

vim.api.nvim_create_user_command("CodexCancel", M.cancel, { desc = "Cancel in-flight Codex requests" })
-- Keep the old command working for existing habits and custom mappings.
vim.api.nvim_create_user_command("ClaudeCancel", M.cancel, { desc = "Alias for CodexCancel" })

return M
