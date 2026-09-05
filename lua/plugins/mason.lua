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
        -- rust
        --
        -- rust-analyzer and rustfmt are NOT here: both are rustup components,
        -- version-locked to the toolchain. lsp/rust_analyzer.lua explains what
        -- breaks when they are not. codelldb is the piece rustup has no
        -- equivalent for -- a DAP-speaking LLDB wrapper, shipped as a prebuilt
        -- release archive, so it needs no runtime of its own.
        "codelldb",
        -- TOML LSP + formatter, single prebuilt binary. Here for Cargo.toml.
        "taplo",
        -- sql
        --
        -- Opinionated SQL formatter (lua/plugins/conform.lua). A pypi package,
        -- which mason installs into a venv of its own -- the system python3 is
        -- enough, nothing lands in it.
        "sqlfmt",
      },
    },
  },
}
