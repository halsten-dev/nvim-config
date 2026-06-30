-- Custom "<leader>a" actions group, shown in the which-key leader menu.
return {
  "folke/which-key.nvim",
  opts = {
    spec = {
      { "<leader>a", group = "Custom actions" },
      { "<leader>ar", "<cmd>lsp restart<cr>", desc = "Restart LSP" },
    },
  },
}
