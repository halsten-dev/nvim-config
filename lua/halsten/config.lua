-- True colour, required by bufferline and gruvbox for correct highlights.
vim.opt.termguicolors = true

-- Hide the command line when idle; it reappears only while typing a `:` command
-- or showing a message. Frees the very bottom row under the statusline.
vim.opt.cmdheight = 0

-- Use the system clipboard (+ register) as the default for yank/delete/paste.
vim.opt.clipboard = "unnamedplus"

-- Rounded borders on every floating window (hover, signature, diagnostics,
-- completion docs, ...). Global default since nvim 0.11.
vim.opt.winborder = "rounded"

-- Indentation
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.expandtab = true

-- No soft-wrap: a line longer than the window runs off the right edge and the
-- view scrolls horizontally instead. Line breaks are yours to place -- nothing
-- wraps or reflows on its own.
vim.opt.wrap = false

-- Keep 4 columns of context to the right (and left) of the cursor once the
-- view scrolls sideways, so you're never typing at the very edge -- the
-- horizontal counterpart of 'scrolloff'.
vim.opt.sidescrolloff = 4

-- Folding: treesitter folds are set up per-buffer in lua/plugins/treesitter.lua.
-- Start with everything unfolded instead of collapsing the whole file on open.
vim.opt.foldlevelstart = 99

-- Line numbers: hybrid. The cursor line shows its absolute number, every other
-- line shows its distance from the cursor -- so 8j / d5k are countable off the
-- gutter without arithmetic.
vim.opt.number = true
vim.opt.relativenumber = true

-- ...but relative numbers are noise when you're not navigating. Drop back to
-- plain absolute numbers in insert mode and in windows that don't have focus,
-- where the distances refer to a cursor you aren't moving.
local numbers = vim.api.nvim_create_augroup("halsten_numbers", { clear = true })

vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "InsertLeave", "WinEnter" }, {
  group = numbers,
  callback = function()
    -- `number` is false in neo-tree, telescope, dap-ui and friends; leave those
    -- windows to manage their own gutter.
    if vim.wo.number and vim.api.nvim_get_mode().mode ~= "i" then
      vim.wo.relativenumber = true
    end
  end,
})

vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost", "InsertEnter", "WinLeave" }, {
  group = numbers,
  callback = function()
    if vim.wo.number then
      vim.wo.relativenumber = false
    end
  end,
})

