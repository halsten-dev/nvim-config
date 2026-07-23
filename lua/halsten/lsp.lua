-- LSP wiring, using Neovim's native client (0.11+). Server definitions live in
-- the top-level `lsp/` directory; this file only decides which ones run and
-- what happens once one attaches.

-- Let blink.cmp advertise its completion capabilities to every server.
local ok, blink = pcall(require, "blink.cmp")
if ok then
  vim.lsp.config("*", { capabilities = blink.get_lsp_capabilities(nil, true) })
end

vim.lsp.enable("gopls")

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

-- Format on save: organize imports, then gofmt. Both are served by gopls, so
-- this needs no formatter plugin and no extra process spawn -- gopls's
-- `source.organizeImports` action is the same logic the goimports binary runs.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("halsten_go_format", { clear = true }),
  pattern = { "*.go", "*.gotmpl" },
  callback = function(ev)
    local client = vim.lsp.get_clients({ bufnr = ev.buf, name = "gopls" })[1]
    if not client then
      return
    end

    local params = vim.lsp.util.make_range_params(0, client.offset_encoding)
    params.context = { only = { "source.organizeImports" }, diagnostics = {} }

    local res = client:request_sync("textDocument/codeAction", params, 3000, ev.buf)
    for _, action in ipairs(res and res.result or {}) do
      if action.edit then
        vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
      end
    end

    vim.lsp.buf.format({ bufnr = ev.buf, id = client.id, timeout_ms = 3000 })
  end,
})
