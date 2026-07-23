-- Popup listing what's available after a prefix key. It reads the `desc` field
-- of existing keymaps, so everything in lua/halsten/remap.lua shows up without
-- being redeclared here -- only the prefix group names need naming.
return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    spec = {
      { "<leader>a", group = "actions/diagnostics" },
      { "<leader>d", group = "debug" },
      { "<leader>t", group = "toggle" },
      { "<leader>s", group = "search" },
      { "<leader>p", group = "project" },
      { "g", group = "goto" },
      { "gr", group = "lsp" },
    },
  },
}
