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
      go = { "goimports", "gofumpt" }, -- imports first, then stricter gofmt
      lua = { "stylua" },
      sh = { "shfmt" },
      bash = { "shfmt" },
      markdown = { "markdownlint-cli2" },
    },
    format_on_save = {
      timeout_ms = 3000,
      lsp_format = "fallback",
    },
  },
}
