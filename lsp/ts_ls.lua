-- TypeScript and JavaScript, including Solid's JSX/TSX. There is no separate
-- Solid LSP: the project's jsxImportSource = "solid-js" supplies the JSX types.
-- Mason's typescript-language-server package includes a fallback TypeScript;
-- the server prefers the project's own TypeScript when available.
return {
  cmd = { "typescript-language-server", "--stdio" },
  filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
  root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
  init_options = { hostInfo = "neovim" },
  on_attach = function(client)
    -- Prettier owns formatting; don't silently switch styles if it is missing.
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,
}
