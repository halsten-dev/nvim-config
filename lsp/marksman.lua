-- Native LSP server definition, discovered off the runtimepath like gopls.
-- Binary: marksman (mason). Markdown links, refs, and outline; no formatting.
return {
  cmd = { "marksman", "server" },
  filetypes = { "markdown", "markdown.mdx" },
  root_markers = { ".marksman.toml", ".git" },
}
