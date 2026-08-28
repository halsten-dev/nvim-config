-- Every keymap lives here.
--
-- Two kinds: global maps set at startup, and buffer-local maps that only make
-- sense once something attaches to a buffer. The latter are exported as
-- functions and called from the module that owns the event -- the map itself
-- is still written here.

local M = {}

vim.g.mapleader = " "

local map = function(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { desc = desc })
end

-- Half-page scroll, animated, cursor kept centred -- including the last
-- screenful of the buffer, where the cursor would otherwise be left sitting on
-- the bottom line.
--
-- Both halves of the move are tweened by hand: the cursor line and the window's
-- top line are computed up front and interpolated together, so the cursor is
-- centred in every frame and lands centred. Doing it this way is what makes the
-- end of the buffer work. Every scrolling primitive Vim offers (<C-e>, <C-d>,
-- 'scrolloff') refuses to move the window once the last line has reached the
-- bottom, so the cursor drifts down the screen as a scroll runs out of buffer.
-- 'topline' set through winrestview() has no such limit -- exactly like `zz`,
-- it will show the end of the buffer at the centre of the window with `~`
-- filler below.
--
-- 'wrap' is off (lua/halsten/config.lua) so one buffer line is one screen line
-- and this line arithmetic is the real geometry.
local dur = 150
local frame_ms = 16

-- One running tween, remembered so a repeat press can pick up where it was
-- headed rather than restarting from whatever is on screen mid-flight.
local anim = {}

local function stop_anim()
  if anim.timer then
    anim.timer:stop()
    anim.timer:close()
    anim.timer = nil
  end
end

local function round(x)
  return math.floor(x + 0.5)
end

local function scroll(dir)
  return function()
    local win = vim.api.nvim_get_current_win()
    local height = vim.api.nvim_win_get_height(win)
    local above = math.floor((height - 1) / 2) -- lines above a centred cursor
    local last = vim.api.nvim_buf_line_count(0)

    -- Holding the key restarts the tween from the previous target, so the moves
    -- add up instead of each press re-scrolling the half page it can still see.
    local base = (anim.timer and anim.win == win) and anim.target or vim.fn.line(".")
    stop_anim()

    local view = vim.fn.winsaveview() -- carries col/curswant, so the column sticks
    local from_line, from_top = view.lnum, view.topline
    local to_line = math.min(math.max(base + dir * math.max(1, math.floor(height / 2)), 1), last)
    -- Clamped at the top only: near the start of the buffer there is nothing to
    -- show above line 1, so the cursor rides above centre there. Near the end
    -- the window is allowed past the last line, which is the point.
    local to_top = math.max(to_line - above, 1)
    if to_line == from_line and to_top == from_top then
      return
    end

    anim.win, anim.target = win, to_line
    local elapsed = 0
    anim.timer = vim.uv.new_timer()
    anim.timer:start(
      0,
      frame_ms,
      vim.schedule_wrap(function()
        -- Give up if the window went away or lost focus mid-tween; winrestview
        -- only ever applies to the current window.
        if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_get_current_win() ~= win then
          stop_anim()
          return
        end
        elapsed = elapsed + frame_ms
        local t = math.min(elapsed / dur, 1)
        local eased = (1 - math.cos(t * math.pi)) / 2 -- ease in-out, monotonic: no bounce
        view.lnum = round(from_line + (to_line - from_line) * eased)
        view.topline = round(from_top + (to_top - from_top) * eased)
        vim.fn.winrestview(view)
        if t >= 1 then
          stop_anim()
        end
        vim.cmd("redraw")
      end)
    )
  end
end

map("n", "<C-d>", scroll(1), "Half page down (animated, centered)")
map("n", "<C-u>", scroll(-1), "Half page up (animated, centered)")

-- Drop the search highlighting and noice's [1/12] counter. Neovim hangs this
-- off <C-l> by default, but that key is window navigation below.
-- The pattern itself survives, so n/N still work and light it back up.
map("n", "<Esc>", "<cmd>nohlsearch<cr>", "Clear search highlight")

-- Window navigation, replacing the <C-w>h/j/k/l prefix.
map("n", "<C-h>", "<C-w>h", "Go to left window")
map("n", "<C-j>", "<C-w>j", "Go to lower window")
map("n", "<C-k>", "<C-w>k", "Go to upper window")
map("n", "<C-l>", "<C-w>l", "Go to right window")

-- Resize the current window width.
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", "Shrink window width")
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", "Grow window width")

-- Pin the current window's width. 'winfixwidth' makes a window refuse
-- *automatic* resizing -- opening or closing a split, the equalise that Vim
-- does on any layout change -- so the cost lands on the unpinned windows
-- instead. <C-Left>/<C-Right> above still work; those are explicit resizes.
-- The same mechanism is applied temporarily around the explorer toggle in
-- lua/plugins/neotree.lua; this is the manual, sticky version.
map("n", "<leader>tw", function()
  local win = vim.api.nvim_get_current_win()
  local pinned = not vim.wo[win].winfixwidth
  vim.wo[win].winfixwidth = pinned
  vim.notify(
    ("Window width %s (%d cols)"):format(pinned and "pinned" or "unpinned", vim.api.nvim_win_get_width(win)),
    vim.log.levels.INFO
  )
end, "Toggle window width lock")

-- Quit every window. Blocks if a buffer has unsaved changes; use :qa! to force.
map("n", "<leader>qq", "<cmd>qall<cr>", "Quit all")

-- Select the whole file.
map("n", "<leader>sa", "ggVG", "Select all")

-- Netrw
map("n", "<leader>pv", vim.cmd.Ex, "Explorer (netrw)")

-- Telescope. Wrapped in functions so telescope isn't require'd at startup --
-- a bare `require("telescope.builtin")` here would force-load it and hard-error
-- if the plugin were ever missing.
map("n", "<leader>f", function() require("telescope.builtin").find_files() end, "Telescope find files")
map("n", "<leader>F", function() require("telescope.builtin").git_files() end, "Telescope find git files")
map("n", "<leader>/", function() require("telescope.builtin").live_grep() end, "Telescope live grep")
map("n", "tb", function() require("telescope.builtin").buffers() end, "Telescope buffers")

-- <leader>s -- telescope pickers (the "search" group).
map("n", "<leader>sh", function() require("telescope.builtin").help_tags() end, "Help tags")
map("n", "<leader>sk", function() require("telescope.builtin").keymaps() end, "Keymaps")
map("n", "<leader>sr", function() require("telescope.builtin").resume() end, "Resume last picker")
map("n", "<leader>so", function() require("telescope.builtin").oldfiles() end, "Recent files")
map("n", "<leader>sc", function() require("telescope.builtin").commands() end, "Commands")
map("n", "<leader>sw", function() require("telescope.builtin").grep_string() end, "Grep word under cursor")
map("n", "<leader>ss", function() require("telescope.builtin").lsp_document_symbols() end, "Document symbols")

-- Buffer tabs (bufferline). Cycle through the open-buffer row.
-- Tab (buffer) navigation under a `t` prefix. Trade-off: the built-in `t`
-- till-char motion now waits timeoutlen before firing, since `t` is a prefix.
map("n", "tl", "<cmd>BufferLineCycleNext<cr>", "Next buffer")
map("n", "th", "<cmd>BufferLineCyclePrev<cr>", "Prev buffer")
-- `:bdelete` also closes every window showing the buffer, so deleting the last
-- buffer in a split collapses the split. Point each of those windows at another
-- buffer first (the alternate one if it is still listed, else the next listed
-- one, else a fresh empty buffer), then delete -- the layout survives.
local function close_buffer()
  local buf = vim.api.nvim_get_current_buf()

  if vim.bo[buf].modified then
    vim.notify("Buffer has unsaved changes", vim.log.levels.WARN)
    return
  end

  local listed = function(b)
    return b ~= buf and vim.api.nvim_buf_is_valid(b) and vim.bo[b].buflisted
  end

  local alt = vim.fn.bufnr("#")
  local replacement = listed(alt) and alt or nil
  if not replacement then
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if listed(b) then
        replacement = b
        break
      end
    end
  end

  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    if replacement then
      vim.api.nvim_win_set_buf(win, replacement)
    else
      vim.api.nvim_win_call(win, function()
        vim.cmd("enew")
      end)
    end
  end

  if vim.api.nvim_buf_is_valid(buf) then
    vim.cmd("bdelete " .. buf)
  end
end

map("n", "tc", close_buffer, "Close buffer")
-- Pick mode: each tab shows a letter, press it to jump to that buffer.
map("n", "tj", "<cmd>BufferLinePick<cr>", "Jump to buffer (pick)")
-- Vertical split holding the same buffer, cursor lands in the new window.
-- `rightbelow` puts it to the right regardless of 'splitright', which is off
-- here, so a plain `:vsplit` would open on the left.
map("n", "ts", "<cmd>rightbelow vsplit<cr>", "Vertical split (focus new)")

-- Wipe the session back to a bare dashboard: every buffer closed, every split
-- and float collapsed to one window showing alpha. Refuses if anything is
-- unsaved, same rule as `tc` above.
--
-- Order matters. Floats (noice, telescope leftovers) must go before `:only`,
-- which errors if a float would be the last window standing. Alpha has to be
-- drawn into the surviving window *before* the old buffers are deleted, or the
-- delete leaves an empty [No Name] behind that alpha would then have to fight.
local function go_home()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buflisted and vim.bo[b].modified then
      vim.notify("Buffer has unsaved changes: " .. vim.fn.bufname(b), vim.log.levels.WARN)
      return
    end
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end

  vim.cmd("silent! tabonly")
  vim.cmd("silent! only")

  local old = vim.api.nvim_list_bufs()

  -- alpha.start toggles *off* when called from inside an alpha buffer, so only
  -- draw when we aren't already there.
  if vim.bo.filetype ~= "alpha" then
    require("alpha").start(false)
  end

  for _, b in ipairs(old) do
    if vim.api.nvim_buf_is_valid(b) then
      pcall(vim.api.nvim_buf_delete, b, { force = false })
    end
  end
end

map("n", "<leader>bh", go_home, "Close everything, back to dashboard")

-- Jump straight back to the last buffer you were in (Vim's alternate buffer,
-- the `#` register / built-in <C-^>). Press again to toggle between the two.
map("n", "<leader>bb", "<cmd>buffer #<cr>", "Previous (alternate) buffer")

-- Accepting a function completion (gopls usePlaceholders) expands a snippet and
-- leaves its parameter tabstops highlighted (SnippetTabstop -> Visual, the
-- "selection" colour). <Esc> exits insert/select mode but doesn't end the
-- snippet session, so that highlight lingers inside the (). End the session on
-- <Esc> too. expr so we still fall through to a normal <Esc> afterwards; not
-- via the `map` helper above, which doesn't take options.
vim.keymap.set({ "i", "s" }, "<Esc>", function()
  if vim.snippet.active() then
    vim.snippet.stop()
  end
  return "<Esc>"
end, { expr = true, desc = "Esc; also end an active snippet" })

-- <leader>a -- actions and diagnostics.
-- <leader>ad is just the current line; <leader>aD lists every diagnostic
-- Neovim knows about, fuzzy-searchable with a preview.
map("n", "<leader>ad", vim.diagnostic.open_float, "Line diagnostics")
map("n", "<leader>aD", function() require("telescope.builtin").diagnostics() end, "All diagnostics")

-- Ask Claude for code and drop it in at the cursor, asynchronously -- see
-- lua/halsten/claude.lua. The two maps differ only in how much of the buffer
-- goes along as context: the function around the cursor, or all of it. Reach
-- for the second one when the answer needs to know about imports, types or
-- helpers defined elsewhere in the file.
map("n", "<leader>ai", function() require("halsten.claude").here("function") end, "Claude fill (function context)")
map("n", "<leader>aI", function() require("halsten.claude").here("buffer") end, "Claude fill (whole buffer)")

-- <leader>g -- git. Lazygit in a float, see lua/halsten/lazygit.lua. The two
-- maps differ only in which repo it starts on: the editor's cwd, or the repo
-- the current file lives in -- they're the same thing until a session has
-- buffers from more than one worktree.
map("n", "<leader>gg", function() require("halsten.lazygit").open() end, "Lazygit (cwd)")
map("n", "<leader>gf", function() require("halsten.lazygit").open_current_file() end, "Lazygit (current file's repo)")

-- LSP. Buffer-local: called from lua/halsten/lsp.lua on LspAttach.
-- The <leader>a maps below duplicate Neovim's built-in grn (rename) and gra
-- (code action) on purpose, so everything lives under one discoverable prefix.
-- Also built in and left alone: grr (references), gri (implementation),
-- grt (type definition), gO (symbols), K (hover).
-- templ compiles `foo.templ` into a sibling `foo_templ.go`, and gopls only ever
-- knows about the generated file -- so `gd` on a component from a .go buffer
-- lands in machine-written code. (`templ lsp` remaps positions itself, but only
-- for requests originating inside a .templ buffer; it never sees this one.)
-- templ emits no //line directives, so there's nothing to read back: instead
-- take the identifier declared on the generated line and find the declaration
-- that produced it in the source. Component names survive codegen verbatim, and
-- raw Go blocks are copied across as-is, so a name match is exact. Returns nil
-- when the source can't be resolved -- the generated file beats a wrong line.
local function templ_source_location(filename, lnum)
  local src = filename:gsub("_templ%.go$", ".templ")
  if src == filename or vim.fn.filereadable(src) ~= 1 then
    return nil
  end

  -- Generated files are large; read only as far as the line we were sent to.
  local target = vim.fn.readfile(filename, "", lnum)[lnum]
  if not target then
    return nil
  end

  local name = target:match("^func%s+([%w_]+)")
    or target:match("^func%s+%b()%s*([%w_]+)")
    or target:match("^type%s+([%w_]+)")
    or target:match("^var%s+([%w_]+)")
    or target:match("^const%s+([%w_]+)")
  if not name then
    return nil
  end

  -- Go identifiers are [%w_] only, so `name` is safe to splice into a pattern.
  local decls = {
    "^%s*templ%s+" .. name .. "%s*%(",
    "^%s*func%s+" .. name .. "%s*[%(%[]",
    "^%s*func%s+%b()%s*" .. name .. "%s*[%(%[]",
    "^%s*type%s+" .. name .. "[%s%[]",
    "^%s*var%s+" .. name .. "[%s=]",
    "^%s*const%s+" .. name .. "[%s=]",
  }

  for i, line in ipairs(vim.fn.readfile(src)) do
    for _, decl in ipairs(decls) do
      if line:match(decl) then
        return { filename = src, lnum = i, col = line:find(name, 1, true), text = line }
      end
    end
  end

  return nil
end

-- Jumping to a location is asynchronous -- the request goes out, the cursor
-- moves whenever the server answers -- so a `zz` tacked onto the mapping would
-- run before the jump and centre the wrong line. `on_list` is the only hook the
-- built-in gives us, and taking it means owning the jump: the tagstack push
-- (what <C-t> walks back down) and the quickfix fallback for multiple results
-- are what vim.lsp.buf.definition would have done for us.
local function goto_centered(fn)
  return function()
    local win = vim.api.nvim_get_current_win()
    local from = vim.fn.getpos(".")
    from[1] = vim.api.nvim_get_current_buf()
    local tagname = vim.fn.expand("<cword>")

    fn({
      on_list = function(t)
        -- Redirect anything that landed in templ-generated Go back to the .templ.
        for _, item in ipairs(t.items) do
          local fname = item.filename or (item.bufnr and vim.api.nvim_buf_get_name(item.bufnr))
          if fname and fname:match("_templ%.go$") then
            local loc = templ_source_location(fname, item.lnum)
            if loc then
              item.bufnr = nil
              item.filename, item.lnum, item.col, item.text = loc.filename, loc.lnum, loc.col, loc.text
            end
          end
        end

        if #t.items > 1 then
          vim.fn.setqflist({}, " ", { title = t.title, items = t.items })
          vim.cmd("botright copen")
          return
        end

        local item = t.items[1]
        local buf = item.bufnr or vim.fn.bufadd(item.filename)

        vim.cmd("normal! m'")
        vim.fn.settagstack(win, { items = { { tagname = tagname, from = from } } }, "t")

        vim.bo[buf].buflisted = true
        vim.api.nvim_win_set_buf(win, buf)
        vim.api.nvim_win_set_cursor(win, { item.lnum, item.col - 1 })
        -- zv opens folds over the target, zz then centres it.
        vim.cmd("normal! zvzz")
      end,
    })
  end
end

function M.on_lsp_attach(client, bufnr)
  local bmap = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = desc })
  end

  bmap("<leader>ar", vim.lsp.buf.rename, "Rename symbol")
  bmap("<leader>ac", vim.lsp.buf.code_action, "Code action")
  bmap("<leader>af", function()
    require("conform").format({ async = true, lsp_format = "fallback" })
  end, "Format file")

  -- Same action save-on-write runs; this is for when you want it mid-edit.
  bmap("<leader>ao", function()
    vim.lsp.buf.code_action({
      context = { only = { "source.organizeImports" }, diagnostics = {} },
      apply = true,
    })
  end, "Organize imports")

  bmap("gd", goto_centered(vim.lsp.buf.definition), "Goto definition")
  bmap("gD", goto_centered(vim.lsp.buf.declaration), "Goto declaration")
  bmap("gy", goto_centered(vim.lsp.buf.type_definition), "Goto type definition")

  if client:supports_method("textDocument/inlayHint") then
    bmap("<leader>th", function()
      local filter = { bufnr = bufnr }
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled(filter), filter)
    end, "Toggle inlay hints")
  end
end

-- Debugging. Buffer-local maps aren't needed here (dap is global state), but
-- the require is deferred so nvim-dap stays lazy until first use.
function M.setup_dap()
  map("n", "<leader>db", function() require("dap").toggle_breakpoint() end, "DAP toggle breakpoint")
  map("n", "<leader>dB", function()
    require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
  end, "DAP conditional breakpoint")
  map("n", "<leader>dc", function() require("dap").continue() end, "DAP continue / start")
  map("n", "<leader>di", function() require("dap").step_into() end, "DAP step into")
  map("n", "<leader>do", function() require("dap").step_over() end, "DAP step over")
  map("n", "<leader>dO", function() require("dap").step_out() end, "DAP step out")
  map("n", "<leader>dr", function() require("dap").repl.toggle() end, "DAP toggle REPL")
  map("n", "<leader>dl", function() require("dap").run_last() end, "DAP run last")
  map("n", "<leader>dx", function() require("dap").terminate() end, "DAP terminate")
  map("n", "<leader>du", function() require("dapui").toggle() end, "DAP toggle UI")
  map("n", "<leader>dt", function() require("dap-go").debug_test() end, "DAP debug nearest test")
end

return M
