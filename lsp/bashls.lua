-- Native LSP server definition, discovered off the runtimepath like gopls.
-- Binary: bash-language-server (mason). It shells out to shellcheck for
-- diagnostics when shellcheck is on PATH -- mason installs both.
return {
  cmd = { "bash-language-server", "start" },
  filetypes = { "sh", "bash" },
  root_markers = { ".git" },
}
