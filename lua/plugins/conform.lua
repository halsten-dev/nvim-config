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
      -- Neovim calls JSX/TSX *react even for Solid; these are filetype names,
      -- not a dependency on React. Conform prefers project-local Prettier,
      -- falling back to Mason's copy, and respects the project's config.
      javascript = { "prettier" },
      javascriptreact = { "prettier" },
      typescript = { "prettier" },
      typescriptreact = { "prettier" },
      css = { "prettier" },
      scss = { "prettier" },
      html = { "prettier" },
      json = { "prettier" },
      jsonc = { "prettier" },
      yaml = { "prettier" },
      -- rumdl ships as a single prebuilt Rust binary, so mason can install it
      -- with no language runtime present. It fixes markdownlint rule
      -- violations -- list markers, blank lines around headings and fences,
      -- trailing whitespace -- and never reflows a paragraph, which is the
      -- behaviour after/ftplugin/markdown.lua leaves textwidth at 0 for.
      -- Kept instead of markdownlint-cli2 so markdown formatting stays
      -- independent of the Node runtime used by the web tooling.
      markdown = { "rumdl" },
      -- rustfmt is a rustup component, not a mason package (see
      -- lsp/rust_analyzer.lua for why the Rust tooling comes from rustup).
      -- Listing it here rather than leaning on the lsp_format fallback keeps
      -- the rule this file exists for: one place decides what formats what.
      -- conform reads the `edition` out of Cargo.toml and passes it through, so
      -- a 2015 or 2024 crate is not formatted as 2021.
      rust = { "rustfmt" },
      -- sqlfmt forces semicolons onto their own line with no opt-out.
      -- sql-formatter keeps them attached by default (newlineBeforeSemicolon
      -- = false), works on stdin without a project config, and allows dialect
      -- and style overrides via .sql-formatter.json in the working directory
      -- or a parent. Uses the Node runtime already needed by the web tooling.
      sql = { "sql_formatter" },
      -- Same binary as the TOML LSP in lsp/taplo.lua.
      toml = { "taplo" },
    },
    format_on_save = {
      timeout_ms = 3000,
      lsp_format = "fallback",
    },
  },
}
