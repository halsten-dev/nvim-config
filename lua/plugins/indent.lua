return {
  "lukas-reineke/indent-blankline.nvim",
  main = "ibl",
  event = "VeryLazy",
  opts = {
    indent = { char = "│" },
    -- Highlight the indent level the cursor sits in.
    scope = { enabled = true, show_start = false, show_end = false },
    exclude = {
      filetypes = { "alpha", "neo-tree", "help", "lazy", "dashboard", "Trouble" },
    },
  },
}
