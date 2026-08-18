-- List continuation. Pressing <CR> at the end of a list item opens the next one
-- already prefixed: `-` stays `-`, `1.` becomes `2.`, and the whole list
-- renumbers when you insert or promote an item in the middle of it.
--
-- Nothing built in does this. The nvim runtime ftplugin sets
-- `comments=fb:*,fb:-,fb:+,n:>` where the `f` flag means "leader on the first
-- line only, never repeat", and 'formatoptions' omits `r`/`o` so <CR> never
-- copies it anyway. Dropping the `f` and adding `ro` gets unordered lists
-- working, but a comment leader is a literal string with no notion of counting,
-- so ordered lists can never continue that way.
--
-- The Lua port of bullets.vim, from the same maintainers. It refuses vimscript
-- configuration outright (`vim.g.bullets_*` does nothing) -- options go through
-- `opts` below, and the `bullets.Config` annotation gives LuaLS completion for
-- the rest of them.
return {
  "bullets-vim/bullets.nvim",
  ft = { "markdown", "text", "gitcommit" },
  ---@module 'bullets'
  ---@type bullets.Config
  opts = {
    -- Mirrors the `ft` list above. The plugin gates its own buffer-local
    -- mappings on this, so leaving it at the default would arm them in
    -- filetypes lazy never loads the plugin for -- harmless, but the two lists
    -- disagreeing is the kind of thing you read back later and mistrust.
    enabled_file_types = { "markdown", "text", "gitcommit" },
  },
}
-- Mappings this installs, all buffer-local to the filetypes above:
--
--   i_<CR>        continue the list          i_<C-CR>  plain newline, no prefix
--   n_o           continue the list          n_gN      renumber the list (also visual)
--   n_<leader>x   toggle checkbox            n_>> n_<<  demote / promote, renumbering
--   i_<C-t>       demote                     i_<C-d>   promote
--
-- <CR> is shared with blink (lua/plugins/blink.lua), mapped there as
-- { "accept", "fallback" }. Its 'fallback' resolves the buffer-local mapping,
-- which is this one -- so <CR> accepts a manually selected completion, and
-- otherwise continues the list.
--
-- Two <CR>s in a row on an item you never typed into removes the empty prefix
-- rather than leaving a bare `-` behind (`delete_last_bullet_if_empty`).
