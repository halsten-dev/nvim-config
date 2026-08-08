-- Native LSP server definition for a-h/templ.
--
-- `templ lsp` is a proxy: it serves the .templ file itself and forwards the Go
-- expressions inside to a gopls it spawns on its own. So gopls must resolve on
-- PATH too -- the mason/bin prepend in halsten/lsp.lua covers both.
--
-- gopls is deliberately NOT given `templ` in its own `filetypes` (lsp/gopls.lua):
-- that would attach a second, unaware client to the same buffer.

return {
  cmd = { "templ", "lsp" },
  filetypes = { "templ" },
  root_markers = { "go.work", "go.mod", ".git" },
}
