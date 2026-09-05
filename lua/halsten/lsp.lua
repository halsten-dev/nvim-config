-- LSP wiring, using Neovim's native client (0.11+). Server definitions live in
-- the top-level `lsp/` directory; this file only decides which ones run and
-- what happens once one attaches.

-- Mason-installed binaries (lua-language-server, etc.) live here but aren't on
-- the login shell's PATH. Prepend once so bare `cmd = { "name" }` in the server
-- defs resolves them, same as a system-wide install.
vim.env.PATH = vim.fn.stdpath("data") .. "/mason/bin:" .. vim.env.PATH

-- Same problem, different directory. Manjaro's `rustup` package shims cargo,
-- rustc and rustfmt straight into /usr/bin, so those resolve already -- but
-- rust-analyzer is not among them: `rustup component add rust-analyzer` only
-- writes a shim to ~/.cargo/bin, which this machine's ~/.zshrc never adds to
-- PATH. Without this line lsp/rust_analyzer.lua's `cmd = { "rust-analyzer" }`
-- would fail to spawn while `rustfmt` formatting worked fine, which is a
-- confusing pair of symptoms to debug.
--
-- Appended, not prepended: anything you have `cargo install`ed should lose to a
-- system package of the same name, whereas mason's copies above are the ones
-- this config actually pins and so have to win.
local cargo_bin = vim.fn.expand("~/.cargo/bin")
if vim.fn.isdirectory(cargo_bin) == 1 then
  vim.env.PATH = vim.env.PATH .. ":" .. cargo_bin
end

-- Let blink.cmp advertise its completion capabilities to every server.
local ok, blink = pcall(require, "blink.cmp")
if ok then
  vim.lsp.config("*", { capabilities = blink.get_lsp_capabilities(nil, true) })
end

vim.lsp.enable("gopls")
vim.lsp.enable("templ")
vim.lsp.enable("lua_ls")
vim.lsp.enable("bashls")
vim.lsp.enable("marksman")
vim.lsp.enable("rust_analyzer")
-- TOML, which in practice means Cargo.toml -- see lsp/taplo.lua.
vim.lsp.enable("taplo")

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("halsten_lsp_attach", { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client then
      return
    end

    require("halsten.remap").on_lsp_attach(client, ev.buf)
  end,
})

-- Format on save is handled by conform.nvim (lua/plugins/conform.lua), which
-- runs goimports + gofumpt for Go and the right formatter per filetype.
