-- Native LSP server definition, discovered off the runtimepath like gopls.
-- Binary: rust-analyzer, installed as a *rustup component* -- deliberately not
-- by mason, and deliberately absent from ensure_installed in
-- lua/plugins/mason.lua.
--
-- Why: rust-analyzer expands proc macros by dynamically loading the compiler's
-- proc-macro bridge, and that ABI is not stable across rustc releases. A
-- rust-analyzer built against a different release than the toolchain that
-- compiled your crates answers every derive macro with "proc macro not
-- expanded" -- which in practice means no completion and no goto on anything
-- touching serde, thiserror, tokio or clap. `rustup component add
-- rust-analyzer` is pinned to the toolchain and moves with `rustup update`,
-- so the two can never drift.
--
-- This matters here specifically because halsten/lsp.lua prepends mason/bin to
-- PATH: a mason copy would shadow the rustup one and silently reintroduce the
-- mismatch. Keep it out of mason.

return {
  cmd = { "rust-analyzer" },
  filetypes = { "rust" },
  -- rust-project.json is the non-cargo entry point (bazel, buck); harmless to
  -- list even if you never write one.
  root_markers = { "Cargo.toml", "rust-project.json", ".git" },
  settings = {
    ["rust-analyzer"] = {
      cargo = {
        -- Run build scripts before analysis. Crates that generate code in
        -- build.rs (bindgen, prost, anything with an OUT_DIR include!) have no
        -- API surface at all without this -- every generated type reads as
        -- unresolved.
        buildScripts = { enable = true },

        -- `allFeatures = true` is left off on purpose. It looks like the
        -- obvious win -- cfg-gated code stops being greyed out -- but crates
        -- with mutually exclusive features (a runtime pick, a backend pick)
        -- then fail to build *at all*, and the failure mode is the whole file
        -- going silent rather than an error you can read. Default features are
        -- what `cargo build` uses, so what you see matches what you ship. Turn
        -- it on per-project in .vscode/settings.json or a rust-analyzer.toml
        -- when a specific crate needs it.
      },

      procMacro = { enable = true },

      -- Clippy instead of plain `cargo check`. It reuses the same build graph,
      -- so the wall-clock cost is one pass either way, and you get the idiom
      -- lints (needless_borrow, redundant_clone, manual_let_else) inline
      -- instead of finding them in CI. Nothing else in this config runs clippy.
      check = { command = "clippy" },

      -- Inlay hints are off until you toggle them (<leader>th), same as gopls.
      -- These settings only decide what gets shown once you do.
      inlayHints = {
        bindingModeHints = { enable = false },
        closureReturnTypeHints = { enable = "with_block" },
        parameterHints = { enable = true },
        typeHints = { enable = true },
        -- Chained method calls are where inferred types actually hide -- an
        -- iterator pipeline is unreadable without them.
        chainingHints = { enable = true },
      },
    },
  },
}
