-- Completion. Not lazy-loaded on purpose: blink registers its LSP capabilities
-- globally, and that has to happen before gopls attaches to the first buffer.
return {
  "saghen/blink.cmp",
  version = "1.*", -- pulls a prebuilt fuzzy-matcher binary; no Rust toolchain needed
  dependencies = { "rafamadriz/friendly-snippets" },
  opts = {
    -- 'default' keeps Neovim's built-in feel: <C-space> opens the menu,
    -- <C-n>/<C-p> cycle, <C-y> accepts, <C-e> dismisses.
    keymap = { preset = "default" },

    appearance = { nerd_font_variant = "mono" },

    completion = {
      documentation = { auto_show = true, auto_show_delay_ms = 200 },
    },

    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },

    fuzzy = { implementation = "prefer_rust_with_warning" },
  },
  opts_extend = { "sources.default" },
}
