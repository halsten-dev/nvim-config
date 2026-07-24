return {
  "karb94/neoscroll.nvim",
  event = "VeryLazy",
  opts = {
    -- No default maps: C-d / C-u are bound in lua/halsten/remap.lua.
    mappings = {},
    easing_function = "sine",
    -- Restore the 'scrolloff' that lua/halsten/remap.lua raised for the
    -- C-d / C-u tween. This fires when the animation ends, so the cursor stays
    -- centred for the whole scroll and the normal scrolloff resumes for j/k the
    -- instant it finishes. No-op for any scroll that didn't raise it.
    post_hook = function()
      local saved = vim.w.halsten_saved_scrolloff
      if saved ~= nil then
        vim.wo.scrolloff = saved
        vim.w.halsten_saved_scrolloff = nil
      end
    end,
  },
}
