return {
  "levouh/tint.nvim",
  event = "VeryLazy",
  opts = {
    -- Only fade foreground of inactive windows. Background left untouched.
    tint = -45,
    saturation = 0.6,
    tint_background_colors = false,
    -- Leave indent-blankline's guides alone. Their fg is already a dim grey
    -- (#504945); tint darkening it in the inactive window drives it to near
    -- black, and it re-tints on every scroll/redraw. "[Ii]bl" covers both the
    -- Ibl* groups and the @ibl.* extmark highlights.
    highlight_ignore_patterns = { "WinSeparator", "Status.*", "TabLine.*", "[Ii]bl" },
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
