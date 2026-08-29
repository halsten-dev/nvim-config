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

-- Spell check. Notes are written in both languages, so both dictionaries are
-- loaded: a word is accepted if it exists in *either*. `fr.utf-8.spl` lives in
-- ~/.local/share/nvim/site/spell (downloaded once; nvim only ships `en`).
-- Tradeoff of the union: an English typo that happens to be a valid French
-- word passes unflagged. Worth it over retyping `:set spelllang` per paragraph.
vim.opt_local.spell = true
vim.opt_local.spelllang = "en_us,fr"

-- 'conceallevel' and 'concealcursor' are deliberately not set here.
-- render-markdown.nvim owns them per-window: it flips conceallevel to 3 while a
-- buffer is rendered and restores your global value the moment it isn't
-- (:RenderMarkdown disable, or leaving the buffer -- not insert mode, which
-- renders too since render_modes = true). Setting them locally would be
-- overwritten on the next render and misleading to read.

-- Formatting is rumdl (lua/plugins/conform.lua), which fixes markdownlint rule
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

-- Spell navigation. `]s`/`[s` (next/previous misspelled word) are built in;
-- these wrap them to do two more things.
--
-- Centre the landing line, the way every other jump in this config does -- `gd`
-- and friends in lua/halsten/remap.lua end on `zvzz` for the same reason. In a
-- wrapped note a word found near the bottom of the window otherwise leaves you
-- reading the sentence it's in with no room below it. `zv` before `zz` opens a
-- fold over the word: treesitter folding is on (lua/plugins/treesitter.lua), so
-- a misspelling inside a collapsed section would be jumped to but not shown.
--
-- Then select the flagged word, so it is ready to be dealt with -- `c` types
-- over it, `z=` offers suggestions for it, `y` grabs it, `zg` (from normal mode)
-- accepts it into the dictionary. `]s` leaves the cursor on the word's first
-- character and spellbadword() reports the word under the cursor, so its length
-- is the exact extent to select. Counted with strchars() rather than `#`
-- because `l` moves by character and the accented half of `spelllang` above is
-- multibyte. 'selection' decides whether the final `l` lands on or one past the
-- last character, hence the two cases.
--
-- pcall because `]s` raises E756 when 'spell' is off -- true in this buffer as
-- set above, but not if you have toggled it off for a paste-heavy stretch. The
-- count is threaded through so `3]s` still skips three words.
local function spelljump(motion)
  return function()
    if not pcall(vim.cmd, ("normal! %d%s"):format(vim.v.count1, motion)) then
      return
    end
    vim.cmd("normal! zvzz")

    local bad = vim.fn.spellbadword()[1]
    if bad == "" then
      return
    end
    local last = vim.fn.strchars(bad) - (vim.o.selection == "exclusive" and 0 or 1)
    vim.cmd("normal! v" .. (last > 0 and last .. "l" or ""))
  end
end

-- Both modes, because the previous press left a selection up. Visual `]s` is
-- built in and *extends* the selection to the next bad word, which is not what
-- a second press means here -- so drop back to normal first. feedkeys' "x" flag
-- runs the <Esc> immediately instead of queueing it behind this function, and
-- the jump to `< rewinds the cursor from the end of the selection to the start
-- of the word: `[s` from mid-word only walks back to that word's own first
-- character, so without this the first press would go nowhere.
local function spellmap(lhs, motion, desc)
  local jump = spelljump(motion)
  vim.keymap.set("n", lhs, jump, { buffer = true, desc = desc })
  vim.keymap.set("x", lhs, function()
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
    pcall(vim.cmd, "normal! `<")
    jump()
  end, { buffer = true, desc = desc })
end

-- Two key pairs onto the same two motions. `]s`/`[s` because that is what the
-- rest of Vim's next/previous jumps look like and what muscle memory from any
-- other config will reach for; `zq`/`zQ` because every other spelling command
-- already lives under `z` (`z=` suggest, `zg` accept, `zw` reject) and the
-- bracket pair is a stretch on an AZERTY layout.
--
-- `q` carries no meaning here -- it was picked because it is the only lowercase
-- letter `z` has left. Everything with a better mnemonic is a real command:
-- `zn`/`zN` toggle 'foldenable', `zj`/`zk` walk folds, `zs`/`ze` scroll
-- horizontally. Since treesitter folding is on (lua/plugins/treesitter.lua),
-- taking any of those would cost something even buffer-locally. `zq`/`zQ` cost
-- nothing, today: nvim claimed the previously-free `zp`/`zP` for blockwise
-- paste in 0.11, so if a future version wants these, move them under <leader>,
-- which is the one namespace that is never taken from you.
spellmap("]s", "]s", "Next misspelling (centred, selected)")
spellmap("[s", "[s", "Prev misspelling (centred, selected)")
spellmap("zq", "]s", "Next misspelling (centred, selected)")
spellmap("zQ", "[s", "Prev misspelling (centred, selected)")
