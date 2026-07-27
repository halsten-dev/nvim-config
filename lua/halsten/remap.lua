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

-- Half-page scroll, animated by neoscroll, cursor kept centred. The obvious
-- "scroll then `zz`" recentre bounces the window: from the top of a buffer
-- neoscroll's ctrl_d drives the window a full half-page down, then zz yanks it
-- straight back up to centre the cursor -- a visible down-then-up jump.
--
-- Instead, raise 'scrolloff' high enough to pin the cursor to the window centre
-- *for the animation only*. neoscroll then scrolls the window by exactly the
-- amount needed to keep the cursor centred, so it lands centred with a single
-- monotonic tween -- no bounce. scrolloff is restored the instant the tween
-- ends (neoscroll's post_hook, lua/plugins/neoscroll.lua), so j/k, search, etc.
-- keep the normal scrolloff.
local dur = 150
local function scroll(fn)
  return function()
    -- Capture the real scrolloff once. A repeat press mid-tween must not save
    -- the already-raised value, or it would never get restored.
    if vim.w.halsten_saved_scrolloff == nil then
      vim.w.halsten_saved_scrolloff = vim.wo.scrolloff
    end
    vim.wo.scrolloff = 999
    require("neoscroll")[fn]({ duration = dur })
    -- If neoscroll had nothing to scroll (e.g. already at EOF) it returns
    -- without ever starting an animation, so its post_hook won't fire. Restore
    -- here so we don't get stuck in the raised-scrolloff (centred) state.
    if not require("neoscroll.scroll").scrolling then
      vim.wo.scrolloff = vim.w.halsten_saved_scrolloff
      vim.w.halsten_saved_scrolloff = nil
    end
  end
end

map("n", "<C-d>", scroll("ctrl_d"), "Half page down (animated, centered)")
map("n", "<C-u>", scroll("ctrl_u"), "Half page up (animated, centered)")

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

-- LSP. Buffer-local: called from lua/halsten/lsp.lua on LspAttach.
-- The <leader>a maps below duplicate Neovim's built-in grn (rename) and gra
-- (code action) on purpose, so everything lives under one discoverable prefix.
-- Also built in and left alone: grr (references), gri (implementation),
-- grt (type definition), gO (symbols), K (hover).
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

  bmap("gd", vim.lsp.buf.definition, "Goto definition")
  bmap("gD", vim.lsp.buf.declaration, "Goto declaration")
  bmap("gy", vim.lsp.buf.type_definition, "Goto type definition")

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
