-- Prose, not source. The global config turns 'wrap' off (lua/halsten/config.lua)
-- because in code a line break is a decision you made and nothing should move
-- it. In a note the opposite holds: a paragraph is one long logical line, and
-- letting it run off the right edge means horizontal scrolling to read your own
-- sentence. Reflow it to the window instead.
vim.opt_local.wrap = true

-- Wrap at the last space before the edge rather than mid-word.
vim.opt_local.linebreak = true

-- Continuation lines keep the indent of the line they came from, so a wrapped
-- bullet or nested list item stays visually inside its own item instead of
-- resetting to column 0.
vim.opt_local.breakindent = true

-- Spell check. Add more languages with `spelllang = "en_us,fr"` -- `:set
-- spell` then pulls each missing dictionary from the nvim runtime on first use.
vim.opt_local.spell = true
vim.opt_local.spelllang = "en_us"

-- 'conceallevel' and 'concealcursor' are deliberately not set here.
-- render-markdown.nvim owns them per-window: it flips conceallevel to 3 while a
-- buffer is rendered and restores your global value the moment it isn't (insert
-- mode, or :RenderMarkdown disable). Setting them locally would be overwritten
-- on the next render and misleading to read.

-- Formatting is markdownlint-cli2 (lua/plugins/conform.lua), which fixes rule
-- violations but never reflows paragraphs. Leaving textwidth at 0 keeps it that
-- way: no hard line breaks get inserted as you type, so a paragraph stays one
-- logical line -- 'wrap' above renders it across several screen rows without
-- touching the file, and diffs stay readable.
vim.opt_local.textwidth = 0

-- Consequence of 'wrap': a paragraph is one logical line, so a bare `j` jumps
-- the whole paragraph. `gj`/`gk` move by screen line instead, which is what you
-- want while editing prose.
--
-- The `v:count == 0` guard keeps both behaviours on the same keys: pressed
-- bare, j/k walk screen lines; with a count, `5j` still means five *logical*
-- lines, so the relative numbers in the gutter (lua/halsten/config.lua) stay
-- countable and `d3j` deletes three real lines, not three visual rows.
--
-- Same split for column motions: `0`/`$` keep going to the true start and end
-- of the logical line, `g0`/`g$` (built in, unmapped) reach the visual ones.
local function bymap(lhs, motion)
  vim.keymap.set({ "n", "x" }, lhs, function()
    return vim.v.count == 0 and ("g" .. motion) or motion
  end, { buffer = true, expr = true, desc = "Move by screen line (markdown)" })
end

bymap("j", "j")
bymap("k", "k")
bymap("<Down>", "j")
bymap("<Up>", "k")

-- Insert mode needs its own pair: the arrows are the only vertical motion you
-- have while typing, and they move by logical line like everything else.
--
-- `<Cmd>` rather than `<C-o>`. <C-o> drops to normal mode for one command,
-- which clamps the cursor from "one past the last character" (a position that
-- only exists in insert mode) onto the last character itself -- so pressing
-- <Up> from the end of a wrapped line lands one column left of where it should.
-- <Cmd> runs the motion without leaving insert mode and keeps the column.
--
-- blink owns <Up>/<Down> too (super-tab preset: select_prev/select_next), and
-- wins while its menu is open. Its 'fallback' action resolves the buffer-local
-- mapping for the key, which is this one -- so menu closed, the arrows move by
-- screen line; menu open, they walk the completion list.
vim.keymap.set("i", "<Down>", "<Cmd>normal! gj<CR>", { buffer = true, desc = "Down a screen line (markdown)" })
vim.keymap.set("i", "<Up>", "<Cmd>normal! gk<CR>", { buffer = true, desc = "Up a screen line (markdown)" })
