-- Popup listing what's available after a prefix key. It reads the `desc` field
-- of existing keymaps, so everything in lua/halsten/remap.lua shows up without
-- being redeclared here -- only the prefix group names need naming.
return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    spec = {
      { "<leader>a", group = "actions/diagnostics" },
      { "<leader>b", group = "buffer" },
      { "<leader>d", group = "debug" },
      { "<leader>t", group = "toggle" },
      { "<leader>s", group = "search" },
      { "<leader>p", group = "project" },
      { "t", group = "tabs/buffers" },
      { "g", group = "goto" },
      { "gr", group = "lsp" },
    },
    -- `<auto>` builds triggers from existing keymaps, but it refuses every
    -- single lowercase letter except g and z (buf.lua, is_safe) -- otherwise it
    -- would swallow motions like d/c/y. Our `t` prefix is exactly that case, so
    -- name it as a manual trigger; manual ones skip the single-letter check.
    triggers = {
      { "<auto>", mode = "nxso" },
      { "t", mode = "n" },
    },
  },
}
