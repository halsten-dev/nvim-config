-- Diagnostic presentation. Neovim shows almost nothing by default: no virtual
-- text, no sign column icons. Everything below is display-only -- it changes
-- how diagnostics look, never which ones gopls reports.
local severity = vim.diagnostic.severity

vim.diagnostic.config({
  -- Inline message at the end of the offending line, errors only. Warnings,
  -- info and hints still exist -- they show as an underline, in the <leader>ad
  -- float, and in the <leader>aD list. They just don't clutter the line.
  virtual_text = {
    severity = severity.ERROR,
    spacing = 2,
    prefix = "●",
    source = "if_many",
  },

  -- No gutter icons.
  signs = false,

  underline = true,

  -- Don't redraw diagnostics while typing -- they go stale mid-keystroke and
  -- the flicker is distracting. They refresh on leaving insert mode.
  update_in_insert = false,

  -- Errors sort above warnings when several land on one line, so the worst
  -- problem is the one shown.
  severity_sort = true,

  -- The floating window opened by <leader>ad (see lua/halsten/remap.lua).
  float = {
    border = "rounded",
    source = true,
  },
})
