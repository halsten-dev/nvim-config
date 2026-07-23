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

-- Half-page scroll, recentering so the cursor stays mid-screen.
--
-- Near the top or bottom of a buffer there's nothing to scroll past, so `zz`
-- can't centre the cursor -- it just drags the view back where it started,
-- which reads as a stutter. Only centre when the cursor is far enough from
-- both edges that centring won't undo the scroll.
local function scroll(key)
  return function()
    vim.cmd("normal! " .. vim.api.nvim_replace_termcodes(key, true, false, true))
    local half = math.floor(vim.fn.winheight(0) / 2)
    local line = vim.fn.line(".")
    if line > half and line < vim.fn.line("$") - half then
      vim.cmd("normal! zz")
    end
  end
end

map("n", "<C-d>", scroll("<C-d>"), "Half page down (centered)")
map("n", "<C-u>", scroll("<C-u>"), "Half page up (centered)")

-- Window navigation, replacing the <C-w>h/j/k/l prefix.
map("n", "<C-h>", "<C-w>h", "Go to left window")
map("n", "<C-j>", "<C-w>j", "Go to lower window")
map("n", "<C-k>", "<C-w>k", "Go to upper window")
map("n", "<C-l>", "<C-w>l", "Go to right window")

-- Netrw
map("n", "<leader>pv", vim.cmd.Ex, "Explorer (netrw)")

-- Telescope. Wrapped in functions so telescope isn't require'd at startup --
-- a bare `require("telescope.builtin")` here would force-load it and hard-error
-- if the plugin were ever missing.
map("n", "<leader>f", function() require("telescope.builtin").find_files() end, "Telescope find files")
map("n", "<leader>F", function() require("telescope.builtin").git_files() end, "Telescope find git files")
map("n", "<leader>/", function() require("telescope.builtin").live_grep() end, "Telescope live grep")
map("n", "<leader>b", function() require("telescope.builtin").buffers() end, "Telescope buffers")

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
