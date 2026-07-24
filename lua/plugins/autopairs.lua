-- Auto-close brackets and quotes: type `(` and get `()` with the cursor
-- between them, likewise {}, [], "", ''. check_ts makes it treesitter-aware so
-- it won't add a pair inside a string or comment. Works in every filetype,
-- Go included.
--
-- Function-call `()` when accepting a completion (e.g. fmt.Println -> ...()) is
-- a separate feature, handled by blink (completion.accept.auto_brackets), not
-- here.
--
-- map_cr = true: pressing <CR> with the cursor between a freshly-opened pair
-- (e.g. `foo(|)`, `if x {|}`) splits it onto its own line and reindents, so the
-- cursor lands inside the block already tabbed in.
--
-- This coexists with blink's Enter-to-accept. blink maps <CR> buffer-locally,
-- which wins the keypress, so a selected completion is still accepted. autopairs
-- maps <CR> globally (expr), and blink's `fallback` (see lua/plugins/blink.lua)
-- delegates to it only when there's nothing to accept -- at which point, with no
-- native pum under blink, it runs the brace-split/indent path.
return {
  "windwp/nvim-autopairs",
  event = "InsertEnter",
  opts = {
    check_ts = true,
    map_cr = true,
  },
}
