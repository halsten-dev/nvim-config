-- Native LSP server definition, discovered off the runtimepath like gopls.
-- Binary: lua-language-server (install separately -- see below).

return {
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  root_markers = { ".luarc.json", ".luarc.jsonc", ".stylua.toml", "stylua.toml", ".git" },
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      -- Silence the "undefined global `vim`" noise when editing this config.
      diagnostics = { globals = { "vim" } },
      -- Let it resolve `require("...")` against the Neovim runtime and every
      -- plugin on the runtimepath, so gotos and completions reach into them.
      workspace = {
        library = vim.api.nvim_get_runtime_file("", true),
        checkThirdParty = false,
      },
      -- Editing config, not shipping a plugin -- no telemetry prompt.
      telemetry = { enable = false },
    },
  },
}
