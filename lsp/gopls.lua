-- Native LSP server definition. Neovim discovers any `lsp/<name>.lua` on the
-- runtimepath, so this file is all `vim.lsp.enable("gopls")` needs -- no
-- nvim-lspconfig required. See `:h lsp-config`.

return {
  cmd = { "gopls" },
  filetypes = { "go", "gomod", "gowork", "gotmpl" },
  root_markers = { "go.work", "go.mod", ".git" },
  settings = {
    gopls = {
      -- Complete symbols from packages that aren't imported yet, and add the
      -- import automatically on accept.
      completeUnimported = true,
      usePlaceholders = true,

      -- staticcheck's extra lint pass, plus the analyzers that aren't on by default.
      staticcheck = true,
      analyses = {
        unusedparams = true,
        unusedwrite = true,
        nilness = true,
        useany = true,
        shadow = true,
      },

      -- Inlay hints are off until you toggle them (<leader>th).
      hints = {
        assignVariableTypes = true,
        compositeLiteralFields = true,
        compositeLiteralTypes = true,
        constantValues = true,
        functionTypeParameters = true,
        parameterNames = true,
        rangeVariableTypes = true,
      },
    },
  },
}
