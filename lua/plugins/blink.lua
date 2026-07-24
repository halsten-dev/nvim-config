-- Completion. Not lazy-loaded on purpose: blink registers its LSP capabilities
-- globally, and that has to happen before gopls attaches to the first buffer.
return {
  "saghen/blink.cmp",
  version = "1.*", -- pulls a prebuilt fuzzy-matcher binary; no Rust toolchain needed
  dependencies = { "rafamadriz/friendly-snippets" },
  opts = {
    -- <Tab> accepts the selected item and expands snippets, then jumps between
    -- placeholders once one is active, and falls through to a normal indent
    -- when the menu is closed. <CR> accepts only when an item is *manually*
    -- selected (list.accept returns false otherwise) -- with no preselection
    -- (see completion.list below) that means <CR> keeps inserting newlines
    -- until you navigate the menu. <C-space> opens the menu, <C-n>/<C-p>
    -- cycle, <C-e> dismisses.
    keymap = {
      preset = "super-tab",
      ["<CR>"] = { "accept", "fallback" },
    },

    appearance = { nerd_font_variant = "mono" },

    completion = {
      documentation = { auto_show = true, auto_show_delay_ms = 200 },

      -- Never preselect an item: the menu opens with nothing highlighted, so
      -- <CR> falls through to a newline until you pick an item with <Tab> or
      -- <C-n>/<C-p>. <Tab> still accepts the first item via select_and_accept,
      -- which selects before accepting regardless of preselection.
      list = {
        selection = {
          preselect = false,
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
