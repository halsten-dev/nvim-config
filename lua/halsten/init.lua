require("halsten.config")
require("halsten.remap")
require("halsten.theme")
require("halsten.diagnostics")
require("halsten.lsp")
-- Loaded at startup rather than lazily from its keymaps, so :ClaudeCancel
-- exists before the first request rather than after it. No plugin deps, so the
-- cost is one small file.
require("halsten.claude")

-- Registers the <leader>d* debug maps (nvim-dap loads on first use).
require("halsten.remap").setup_dap()
