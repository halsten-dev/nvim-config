-- Formatting layer. Runs the standalone formatter binaries (mason-installed,
-- resolved via the PATH prepend in halsten/lsp.lua) instead of leaning on each
-- LSP's built-in formatter. One place decides what formats what.
--
-- `lsp_format = "fallback"` means: for a filetype with no entry below, fall
-- back to whatever the attached LSP offers -- so a newly-enabled server still
-- formats without a conform entry.
return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  opts = {
    formatters_by_ft = {
      -- goimports = gofmt formatting + import management. gofumpt is dropped on
      -- purpose: its non-configurable ruleset deletes the blank line between an
      -- assignment and a following `if err != nil {`, and we want to keep it.
      go = { "goimports" },
      -- `templ fmt` is the only formatter for .templ; it handles both the
      -- markup and the embedded Go.
      templ = { "templ" },
      lua = { "stylua" },
      sh = { "shfmt" },
      bash = { "shfmt" },
      -- rumdl ships as a single prebuilt Rust binary, so mason can install it
      -- with no language runtime present. It fixes markdownlint rule
      -- violations -- list markers, blank lines around headings and fences,
      -- trailing whitespace -- and never reflows a paragraph, which is the
      -- behaviour after/ftplugin/markdown.lua leaves textwidth at 0 for.
      -- markdownlint-cli2 does the same job but is npm-only, and there is no
      -- node on this machine for mason to install it with.
      markdown = { "rumdl" },
      -- rustfmt is a rustup component, not a mason package (see
      -- lsp/rust_analyzer.lua for why the Rust tooling comes from rustup).
      -- Listing it here rather than leaning on the lsp_format fallback keeps
      -- the rule this file exists for: one place decides what formats what.
      -- conform reads the `edition` out of Cargo.toml and passes it through, so
      -- a 2015 or 2024 crate is not formatted as 2021.
      rust = { "rustfmt" },
      -- sqlfmt (shandy-sqlfmt) is to SQL what gofmt is to Go: one style, no
      -- options, reads stdin. Picked over sqlfluff, which conform will only run
      -- when the project has a .sqlfluff or pyproject.toml at its root
      -- (require_cwd), so a scratch query in a throwaway buffer would silently
      -- not format -- and over sql-formatter, which is npm-only.
      --
      -- The cost of a real parser instead of a whitespace pass: sqlfmt refuses
      -- a file it cannot parse rather than mangling it, so some vendor-specific
      -- DDL comes back as a conform error and the buffer is left untouched.
      sql = { "sqlfmt" },
      -- Same binary as the TOML LSP in lsp/taplo.lua.
      toml = { "taplo" },
    },
    format_on_save = {
      timeout_ms = 3000,
      lsp_format = "fallback",
    },
  },
}
