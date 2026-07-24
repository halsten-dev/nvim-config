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
map("n", "tc", "<cmd>bdelete<cr>", "Close buffer")
-- Pick mode: each tab shows a letter, press it to jump to that buffer.
map("n", "tj", "<cmd>BufferLinePick<cr>", "Jump to buffer (pick)")

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
