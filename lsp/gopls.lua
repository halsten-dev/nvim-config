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

        -- Silence staticcheck's ST* "stylecheck" group: package/exported-symbol
        -- comment formatting, naming conventions, etc. These underline whole
        -- comment blocks for not matching Go house style -- noise, not bugs.
        -- SA (correctness), S (simplify) and U (unused) staticcheck checks stay on.
        ST1000 = false, -- package comment present / format
        ST1001 = false, -- dot imports
        ST1003 = false, -- naming conventions (initialisms, etc.)
        ST1005 = false, -- error string format
        ST1006 = false, -- receiver naming
        ST1008 = false, -- error should be last return value
        ST1011 = false, -- time.Duration variable naming
        ST1012 = false, -- error variable naming (errFoo)
        ST1013 = false, -- HTTP status code constants
        ST1015 = false, -- default case ordering in switch
        ST1016 = false, -- consistent receiver names
        ST1017 = false, -- yoda conditions
        ST1018 = false, -- avoid zero-width/control runes in strings
        ST1019 = false, -- duplicate imports
        ST1020 = false, -- exported function comment form
        ST1021 = false, -- exported type comment form
        ST1022 = false, -- exported var/const comment form
        ST1023 = false, -- redundant type in var declaration
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
