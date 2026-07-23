return {
  "nvim-telescope/telescope.nvim",
  version = "*",
  cmd = "Telescope", -- keymaps live in lua/halsten/remap.lua
  dependencies = {
    "nvim-lua/plenary.nvim",
    -- Compiled C sorter. Without load_extension("fzf") below, telescope
    -- silently falls back to its Lua sorter and this build is wasted.
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    -- Replaces vim.ui.select with a searchable telescope window: DAP config
    -- and process pickers, LSP code actions, everything.
    "nvim-telescope/telescope-ui-select.nvim",
  },
  init = function()
    -- Telescope is lazy, so the ui-select extension hasn't run yet and
    -- vim.ui.select is still Neovim's numbered `inputlist` prompt. Stand in
    -- for it until the first call, then hand over to the real one.
    local builtin = vim.ui.select
    local shim
    shim = function(...)
      require("lazy").load({ plugins = { "telescope.nvim" } })
      -- If loading telescope didn't install the override, restore Neovim's
      -- own picker. Without this the next line calls the shim again, forever.
      if vim.ui.select == shim then
        vim.ui.select = builtin
      end
      return vim.ui.select(...)
    end
    vim.ui.select = shim
  end,
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
        ["ui-select"] = {
          require("telescope.themes").get_dropdown({}),
        },
      },
    })

    telescope.load_extension("fzf")
    -- Hyphen, not underscore -- the extension module is `ui-select.lua`, and
    -- load_extension("ui_select") errors with "extension doesn't exist".
    telescope.load_extension("ui-select")
  end,
}
