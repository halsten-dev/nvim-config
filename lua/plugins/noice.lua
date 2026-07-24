return {
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "rcarriga/nvim-notify", -- backend for notifications
  },
  opts = {
    -- Drop the plugin-manager install/update chatter that stacks up in the
    -- top-right on startup (mason, mason-tool-installer, lazy, nvim-treesitter).
    -- Matched by notification title. `error = false` keeps genuine install
    -- *failures* visible -- only routine INFO/WARN notices are skipped.
    routes = {
      {
        filter = {
          event = "notify",
          error = false,
          cond = function(msg)
            local title = msg.opts and msg.opts.title
            return title == "mason.nvim"
              or title == "mason-tool-installer"
              or title == "lazy.nvim"
              or title == "nvim-treesitter"
          end,
        },
        opts = { skip = true },
      },
    },
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
