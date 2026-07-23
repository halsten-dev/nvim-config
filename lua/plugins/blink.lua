-- Completion. Not lazy-loaded on purpose: blink registers its LSP capabilities
-- globally, and that has to happen before gopls attaches to the first buffer.
return {
  "saghen/blink.cmp",
  version = "1.*", -- pulls a prebuilt fuzzy-matcher binary; no Rust toolchain needed
  dependencies = { "rafamadriz/friendly-snippets" },
  opts = {
    -- <Tab> accepts the selected item and expands snippets, then jumps between
    -- placeholders once one is active, and falls through to a normal indent
    -- when the menu is closed. <CR> is left alone -- it always inserts a
    -- newline. <C-space> opens the menu, <C-n>/<C-p> cycle, <C-e> dismisses.
    keymap = { preset = "super-tab" },

    appearance = { nerd_font_variant = "mono" },

    completion = {
      documentation = { auto_show = true, auto_show_delay_ms = 200 },

      -- Upstream's recommended pairing for super-tab: don't preselect an item
      -- while a snippet is active, so <Tab> inside a snippet moves to the next
      -- placeholder instead of accepting whatever happened to be highlighted.
      list = {
        selection = {
          preselect = function()
            return not require("blink.cmp").snippet_active({ direction = 1 })
          end,
        },
      },
    },

    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },

    fuzzy = { implementation = "prefer_rust_with_warning" },
  },
  opts_extend = { "sources.default" },
}
