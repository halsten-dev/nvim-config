return {
  "akinsho/bufferline.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  event = "VeryLazy",
  opts = {
    options = {
      -- Show open buffers as tabs (not vim tabpages).
      mode = "buffers",
      diagnostics = "nvim_lsp",
      -- Show a warning sign only when the buffer has an error. Warnings and
      -- hints add nothing to the tab. Jump letters show under <leader>bj.
      diagnostics_indicator = function(_, _, diag)
        return diag.error and " ⚠" or ""
      end,
      show_buffer_close_icons = false,
      show_close_icon = false,
      -- Keep the neo-tree sidebar clear of the tab row.
      offsets = {
        { filetype = "neo-tree", text = "File Explorer", separator = true },
      },
    },
  },
}
