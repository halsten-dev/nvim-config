-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local function t(keys)
  return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

vim.keymap.set("n", "<C-d>", function()
  vim.api.nvim_feedkeys(t("<C-d>zz"), "nx", false)
end, { desc = "Scroll down and center" })

vim.keymap.set("n", "<C-u>", function()
  vim.api.nvim_feedkeys(t("<C-u>zz"), "nx", false)
end, { desc = "Scroll up and center" })
