-- Mason manages the external tool binaries (LSP servers, formatters, linters)
-- under stdpath("data")/mason/bin. This config wires LSP natively via
-- vim.lsp.enable, so mason here is just the installer/updater -- no
-- mason-lspconfig bridge. lsp.lua prepends mason/bin to PATH so the bare
-- `cmd = { "name" }` in each lsp/<name>.lua resolves these.
return {
  {
    "mason-org/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
    opts = {},
  },

  -- Declares which tools to keep installed and installs any that are missing on
  -- startup. :MasonToolsUpdate refreshes them.
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason-org/mason.nvim" },
    event = "VeryLazy",
    opts = {
      ensure_installed = {
        -- go
        "gopls",
        "gofumpt",
        "goimports",
        "golangci-lint",
        "delve",
        -- LSP *and* formatter for .templ -- the same binary does both.
        "templ",
        -- lua
        "lua-language-server",
        "stylua",
        -- bash
        "bash-language-server",
        "shfmt",
        "shellcheck",
        -- markdown
        "marksman",
        -- Rule-fixing markdown formatter (lua/plugins/conform.lua). Picked
        -- over the equivalent markdownlint-cli2, which is an npm package and
        -- so uninstallable without a node runtime.
        "rumdl",
      },
    },
  },
}
