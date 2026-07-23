return {
  "nvim-telescope/telescope.nvim",
  version = "*",
  cmd = "Telescope", -- keymaps live in lua/halsten/remap.lua
  dependencies = {
    "nvim-lua/plenary.nvim",
    -- Compiled C sorter. Without load_extension("fzf") below, telescope
    -- silently falls back to its Lua sorter and this build is wasted.
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
  },
  config = function()
    local telescope = require("telescope")

    telescope.setup({
      extensions = {
        fzf = {
          fuzzy = true,
          override_generic_sorter = true,
          override_file_sorter = true,
          case_mode = "smart_case",
        },
      },
    })

    telescope.load_extension("fzf")
  end,
}
