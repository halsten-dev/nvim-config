-- LSP wiring, using Neovim's native client (0.11+). Server definitions live in
-- the top-level `lsp/` directory; this file only decides which ones run and
-- what happens once one attaches.

-- Mason-installed binaries (lua-language-server, etc.) live here but aren't on
-- the login shell's PATH. Prepend once so bare `cmd = { "name" }` in the server
-- defs resolves them, same as a system-wide install.
vim.env.PATH = vim.fn.stdpath("data") .. "/mason/bin:" .. vim.env.PATH

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
