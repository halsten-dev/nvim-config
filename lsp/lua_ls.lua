-- Native LSP server definition, discovered off the runtimepath like gopls.
-- Binary: lua-language-server (install separately -- see below).

return {
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  root_markers = { ".luarc.json", ".luarc.jsonc", ".stylua.toml", "stylua.toml", ".git" },
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      diagnostics = {
        -- Silence the "undefined global `vim`" noise when editing this config.
        globals = { "vim" },
        -- lazy.nvim is required under several names across the plugin ecosystem,
        -- so lua_ls can't pick a canonical one and flags every `require("lazy")`
        -- with "different-requires". Noise for a config, not a real problem.
        disable = { "different-requires" },
      },
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
