return {
  "levouh/tint.nvim",
  event = "VeryLazy",
  opts = {
    -- Only fade foreground of inactive windows. Background left untouched.
    tint = -45,
    saturation = 0.6,
    tint_background_colors = false,
    highlight_ignore_patterns = { "WinSeparator", "Status.*", "TabLine.*" },
    window_ignore_function = function(winid)
      local bufid = vim.api.nvim_win_get_buf(winid)
      local ft = vim.bo[bufid].filetype
      local floating = vim.api.nvim_win_get_config(winid).relative ~= ""
      -- Leave sidebars, dashboard and floats at full brightness.
      local skip = { ["neo-tree"] = true, alpha = true, ["dap-repl"] = true }
      return floating or skip[ft] == true
    end,
  },
}
