require("halsten.config")
require("halsten.remap")
require("halsten.theme")
require("halsten.diagnostics")
require("halsten.lsp")

-- Registers the <leader>d* debug maps (nvim-dap loads on first use).
require("halsten.remap").setup_dap()
