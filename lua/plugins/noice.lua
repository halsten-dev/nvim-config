return {
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "rcarriga/nvim-notify", -- backend for notifications
  },
  opts = {
    lsp = {
      -- Render LSP hover / signature help through noice's markdown.
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
      },
    },
    presets = {
      bottom_search = true,         -- keep `/` and `?` search at the bottom
      command_palette = true,       -- cmdline + completions as a centered popup
      long_message_to_split = true, -- send long messages to a split, not a modal
      lsp_doc_border = true,        -- border on hover / signature popups
    },
  },
}
