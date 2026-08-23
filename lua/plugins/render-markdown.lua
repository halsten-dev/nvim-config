-- In-buffer markdown rendering: heading backgrounds, real bullet glyphs, drawn
-- table borders, checkbox icons, callout blocks, fenced-code backgrounds. Pure
-- treesitter + extmarks -- no browser, no node, no preview window. The buffer
-- you edit is the buffer you read.
--
-- Depends on conceallevel = 2, set per-buffer in after/ftplugin/markdown.lua.
-- Without it the plugin loads and does nothing visible.
--
-- Anti-conceal is on by default: the line under the cursor drops back to raw
-- markdown so you always edit the real text, never a rendered stand-in.
return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown" },
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {
    -- Render in insert mode too. The default is { "n", "c", "t" }, which tears
    -- every extmark down on InsertEnter and rebuilds it on InsertLeave -- and
    -- because the sign module (on by default) puts heading icons in the gutter
    -- while 'signcolumn' is left at "auto", that teardown collapses the sign
    -- column from one cell to zero and shifts the whole buffer sideways every
    -- time you start typing. Rendering in every mode keeps the signs, so the
    -- gutter width never changes and nothing reflows.
    --
    -- Anti-conceal still drops the cursor line back to raw markdown, which is
    -- the point -- you edit real text. That line alone re-renders as you move
    -- off it; the rest of the buffer now holds still.
    render_modes = true,

    -- Offer the plugin's own completions (callout kinds, checkbox states) as an
    -- LSP source, which is what blink already consumes -- so `- [` and `> [!`
    -- complete alongside marksman's wiki-link suggestions with no extra wiring.
    completions = { lsp = { enabled = true } },
  },
}
