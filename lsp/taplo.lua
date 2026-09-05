-- Native LSP server definition, discovered off the runtimepath like gopls.
-- Binary: taplo (mason). TOML LSP *and* formatter -- lua/plugins/conform.lua
-- calls the same binary as `taplo format`.
--
-- Here for Cargo.toml, which is where Rust work actually spends its TOML time.
-- taplo ships the crates.io / Cargo manifest schema, so you get completion and
-- validation on the real key set ([dependencies], [features], workspace
-- inheritance) rather than generic "this is valid TOML".
return {
  cmd = { "taplo", "lsp", "stdio" },
  filetypes = { "toml" },
  root_markers = { ".taplo.toml", "taplo.toml", ".git" },
}
