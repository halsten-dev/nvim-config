# nvim

Personal Neovim configuration: Go, templ, Rust, SolidJS / TypeScript / JavaScript, Lua, shell, SQL and markdown, built on Neovim's own LSP client. lazy.nvim manages plugins, mason manages the external tool binaries, and there is no distribution layer in between — every plugin spec in `lua/plugins/` and every server definition in `lsp/` is hand-written and commented with the reasoning behind it.

## Requirements at a glance

| Layer | What | Required? |
| --- | --- | --- |
| Editor | Neovim ≥ 0.11 | yes |
| Build | `base-devel` (make + gcc), `git`, `curl`, `unzip`, `tar`, `gzip`, `tree-sitter-cli` | yes |
| Runtime | Go toolchain | yes — mason builds the Go tooling with it |
| Runtime | `rustup` toolchain | yes for Rust — supplies `rust-analyzer`, `rustfmt` and `clippy` |
| Runtime | Python 3 | yes in practice — mason installs `sqlfmt` into a venv with it |
| Runtime | Node.js ≥ 22.22.2 + npm (prefer current LTS) | yes for SolidJS / TS / JS tooling and shell LSP |
| Search | `ripgrep`, `fd` | yes in practice — telescope and grug-far depend on them |
| Clipboard | `wl-clipboard` on Wayland; `xclip` on X11 | yes for system clipboard yank/paste |
| Git UI | `lazygit` | optional — `<leader>gg` / `<leader>gf` are dead without it |
| AI | `codex` CLI | optional — `<leader>ai` / `<leader>aI` are dead without it |
| Display | any Nerd Font | yes in practice — icons and separators break without one |

## Neovim

**Neovim 0.11 or newer.** The config leans on APIs that do not exist before it:

- `lsp/<name>.lua` discovery on the runtimepath plus `vim.lsp.enable()` — this is why there is no `nvim-lspconfig` in the plugin list.
- `vim.lsp.config("*", ...)`, used in `lua/halsten/lsp.lua` to hand blink's completion capabilities to every server at once.
- `vim.o.winborder`, set globally in `lua/halsten/config.lua` so floats inherit a rounded border instead of each caller passing one.
- `vim.fn.jobstart(..., { term = true })`, the replacement for `termopen()`, used by the lazygit float.

## System packages

Everything below is available from the official repositories on Arch and Manjaro.

| Package | Why it is needed |
| --- | --- |
| `neovim` | the editor |
| `git` | lazy.nvim bootstraps itself with `git clone`, and `<leader>F` is telescope's `git_files` |
| `base-devel` | `make` and a C compiler: telescope-fzf-native is built with `make`, and nvim-treesitter compiles every parser locally |
| `curl`, `wget`, `unzip`, `tar`, `gzip` | mason downloads and unpacks release archives with these (usually present already) |
| `ripgrep` | telescope `live_grep` / `grep_string` and the whole of grug-far |
| `fd` | telescope's file finder prefers it; without it the picker falls back to `rg --files`, then to `find` |
| `wl-clipboard` | `wl-copy` / `wl-paste`, Neovim's system clipboard provider on KDE Wayland; use `xclip` instead on X11 |
| `go` | the Go toolchain, and what mason uses to build most of the Go tooling |
| `rustup` | the Rust toolchain manager — `rustc`, `cargo`, `rustfmt`, `clippy` and `rust-analyzer` all come from it. See [Rust](#rust) below; **do not** also install the `rust` package, they conflict |
| `python` | mason builds a venv with it to install `sqlfmt`, the SQL formatter. Already present on any Manjaro install |
| `nodejs`, `npm` | runtime and package manager for TypeScript LSP, ESLint LSP, Prettier, `bash-language-server`, and SolidJS projects |
| `tree-sitter-cli` | required by the nvim-treesitter `main` branch to build parsers; without the `tree-sitter` binary startup fills `:messages` with `ENOENT ... (cmd): 'tree-sitter'` install errors |
| `lazygit` | the `<leader>gg` / `<leader>gf` float in `lua/halsten/lazygit.lua` |
| a Nerd Font | `ttf-hack-nerd` or similar — see below |

Install the lot:

```sh
sudo pacman -S --needed neovim git base-devel curl wget unzip \
  ripgrep fd go rustup python nodejs npm tree-sitter-cli lazygit ttf-hack-nerd \
  wl-clipboard
```

`rustup` installs no toolchain of its own — see [Rust](#rust) for the two commands that follow.

On Debian or Ubuntu the equivalents are `build-essential` for `base-devel` and `fd-find` for `fd` — note that the latter installs the binary as `fdfind`, so symlink it to `fd` somewhere on `$PATH` or telescope will not find it. Neovim's repository versions are frequently older than 0.11; prefer the official AppImage or a source build there.

### System clipboard (KDE / Manjaro)

`lua/halsten/config.lua` already sets `clipboard = "unnamedplus"`, so normal yank/delete/paste uses the system clipboard. Neovim still needs an external clipboard provider — KDE's clipboard manager alone is not enough.

For a **Wayland** session (`echo $XDG_SESSION_TYPE`):

```sh
sudo pacman -S --needed wl-clipboard
```

This supplies `wl-copy` and `wl-paste`; Neovim detects them automatically. Restart Neovim after installing and run `:checkhealth vim.provider` to check clipboard detection. No extra plugin or Lua configuration is needed. On **X11**, install `xclip` instead.

### Fonts

A Nerd Font is not decorative here. `nvim-web-devicons` feeds bufferline, lualine, neo-tree and render-markdown; blink is configured with `nerd_font_variant = "mono"`; and lualine draws powerline separators. Without one you get replacement boxes across the whole UI. Any patched font works — this machine has `ttf-hack-nerd` and `ttf-meslo-nerd-font-powerlevel10k`. Set it in your terminal emulator, not in Neovim.

## Language runtimes

### Go

**Go** is required. Mason builds `gopls`, `goimports`, `gofumpt`, `golangci-lint`, `delve` and `templ` with the Go toolchain, so without it most of the tool list below silently fails to install.

### Rust

**`rustup`, not the `rust` package.** They conflict on Arch and Manjaro — `rustup` already `Provides` `rust`, `cargo`, `rustfmt` and `rust-analyzer`, so installing both is impossible, and picking the plain `rust` package leaves you with no way to add the `rust-analyzer` and `rust-src` components this config needs.

```sh
sudo pacman -S rustup
rustup default stable                        # rustc, cargo, rustfmt, clippy
rustup component add rust-analyzer rust-src  # the LSP, and std's sources for it
```

The second command is not optional and neither part of the third is:

- `rustup default stable` is what actually downloads a toolchain. Freshly installed, `rustup` is an empty manager — `cargo build` fails with "no default toolchain configured" until you run it. The default profile brings `rustfmt` (the formatter wired into conform) and `clippy` (what `lsp/rust_analyzer.lua` runs in place of `cargo check`) with it, so neither needs a step of its own.
- `rust-analyzer` is **not** in the default profile and has to be added by hand.
- `rust-src` is what lets rust-analyzer index the standard library. Without it, goto-definition on `Vec::push` goes nowhere and completion on any `std` type comes back empty — your own crate still analyses fine, which makes it read as a rust-analyzer bug rather than a missing component.

Two things worth knowing about how the pieces get found:

- Manjaro's `rustup` package shims `cargo`, `rustc`, `rustfmt`, `clippy-driver` and `cargo-clippy` into `/usr/bin`, so those are on `$PATH` immediately. `rust-analyzer` is **not** among them — `rustup component add` only writes a shim to `~/.cargo/bin`, which this machine's `~/.zshrc` never exports. `lua/halsten/lsp.lua` appends that directory to Neovim's own `$PATH` for exactly this reason, so the editor resolves it either way. Add it to your shell too if you want `cargo install`ed binaries on the command line:

  ```sh
  echo 'export PATH=$PATH:$HOME/.cargo/bin' >> ~/.zshrc
  ```

- rust-analyzer comes from rustup rather than mason **on purpose**, and is deliberately absent from `ensure_installed`. It expands derive macros by loading the compiler's proc-macro bridge, and that ABI is not stable across rustc releases: a mason build from a different release than your toolchain leaves every `#[derive(...)]` unexpanded, so anything touching serde, thiserror, tokio or clap gets no completion and no goto. The rustup component is version-locked to the toolchain and follows it on `rustup update`. And since `lua/halsten/lsp.lua` *prepends* mason's bin directory, a mason copy would shadow the correct one even if you had both — the full reasoning is in `lsp/rust_analyzer.lua`.

`rustup update` upgrades the toolchain and all of its components together, rust-analyzer included.

### Python

Present on any Manjaro install, and used only indirectly: mason installs `sqlfmt` from PyPI by building a virtualenv inside its own package directory. Nothing is written to the system Python and no `pip` on `$PATH` is needed — `python3 -m venv` is enough, and it works here out of the box.

### Node

**Node.js ≥ 22.22.2 and npm** are required for the current TypeScript language server (prefer the current Node LTS). Mason uses npm to install `typescript-language-server`, `eslint-lsp`, `prettier` and `bash-language-server`; Node runs them. Without it, TS/JS buffers have no LSP or Prettier, and shell buffers have no LSP — `shfmt` and `shellcheck` are standalone binaries and are unaffected.

```sh
sudo pacman -S --needed nodejs npm
node --version
npm --version
```

Nothing else in the config needs a Ruby, PHP or Java toolchain. blink.cmp's fuzzy matcher and the `rumdl` markdown formatter are themselves Rust programs, but both ship prebuilt binaries and never go through `cargo` — they worked fine before `rustup` was installed and do not depend on it now.

### SolidJS / TypeScript / JavaScript

The same setup handles `.tsx`, `.jsx`, `.ts` and `.js`:

- **LSP:** `typescript-language-server` (`lsp/ts_ls.lua`) provides completion, auto-imports, hover, definitions, rename and type diagnostics through the existing blink/keymap setup. No separate Solid language server or React packages are needed.
- **Formatting:** Prettier runs on save and with `<leader>af`. Conform prefers the project's `node_modules/.bin/prettier`, falling back to Mason's copy, and reads the project's Prettier configuration. CSS, SCSS, HTML, JSON/JSONC and YAML also use Prettier; existing language formatters are unchanged.
- **Linting:** `eslint-lsp` (`lsp/eslint.lua`) supplies diagnostics and code actions using the project's ESLint installation. It only attaches when an `eslint.config.*` or `.eslintrc*` file exists. Solid's reactivity checks come from `eslint-plugin-solid`, not TypeScript. Fixes are explicit via `<leader>ac`, not automatic on save.
- **Highlighting/folding:** Tree-sitter already includes `javascript` (also JSX), `typescript` and `tsx`; `css` is included too. Neovim calls JSX/TSX filetypes `javascriptreact` / `typescriptreact` even in Solid projects — do not rename them.

Project dependencies belong in the project, **not** in this Neovim repository:

| Dependency | Role |
| --- | --- |
| `solid-js` | Solid runtime and JSX types; supplied by a Solid starter |
| `vite`, `vite-plugin-solid` | dev server and Solid JSX compilation for a Vite-based starter |
| `typescript@6` | project-local compiler and types used by the LSP; see compatibility note below |
| `prettier` | project-pinned formatting, shared by the editor and CLI |
| `eslint@10`, `@eslint/js@10` | lint engine and recommended JavaScript rules; ESLint 10 requires flat config |
| `typescript-eslint` | TypeScript parser and lint rules |
| `eslint-plugin-solid` | Solid-specific JSX and reactivity rules |
| `eslint-config-prettier` | disables lint rules that conflict with Prettier |
| `globals` | browser globals for the ESLint config |

For a new Vite-based Solid TypeScript app (skip scaffolding if you already have a project):

```sh
npm create vite@latest my-solid-app -- --template solid-ts
cd my-solid-app
npm install
```

Then, from the project directory, add the development tools:

```sh
npm install -D typescript@6 prettier eslint@10 @eslint/js@10 \
  typescript-eslint eslint-plugin-solid eslint-config-prettier globals
```

**TypeScript compatibility:** use TypeScript 6 for this setup. TypeScript 7 removed `lib/tsserver.js`, which `typescript-language-server` needs, and the current `typescript-eslint` supports TypeScript `<6.1`. Mason also supplies TypeScript 6 as the server's fallback. The explicit version above keeps the project compiler compatible even if a starter defaults to a newer major.

Keep the starter's TypeScript settings. In the config that covers your source files (`tsconfig.json` or `tsconfig.app.json`), these options make JSX use **Solid**, not React:

```json
{
  "compilerOptions": {
    "jsx": "preserve",
    "jsxImportSource": "solid-js"
  }
}
```

Merge those options rather than replacing the whole config. For a mixed JS/TS project, also set `allowJs: true`; add `checkJs: true` if you want TypeScript diagnostics in `.js`/`.jsx`. A JavaScript-only project can put these options in `jsconfig.json`.

ESLint 10 requires flat config (`eslint.config.*`); `.eslintrc*` is no longer supported by ESLint 10. The LSP still detects those legacy files for older projects. Current `typescript-eslint`, `eslint-plugin-solid` and `eslint-config-prettier` releases support ESLint 10.

If the starter has no ESLint config, create `eslint.config.mjs` at the project root (otherwise merge the Solid presets into its existing flat config):

```js
import { defineConfig } from "eslint/config";
import js from "@eslint/js";
import tseslint from "typescript-eslint";
import solid from "eslint-plugin-solid";
import globals from "globals";
import prettier from "eslint-config-prettier";

export default defineConfig([
  { ignores: ["dist/**", ".output/**", ".vinxi/**"] },
  {
    files: ["**/*.{js,jsx}"],
    extends: [js.configs.recommended, solid.configs["flat/recommended"]],
  },
  {
    files: ["**/*.{ts,tsx}"],
    extends: [tseslint.configs.recommended, solid.configs["flat/typescript"]],
  },
  {
    files: ["src/**/*.{js,jsx,ts,tsx}"],
    languageOptions: { globals: globals.browser },
  },
  prettier,
]);
```

Prettier works without a config; add `.prettierrc.json` in the project if you want to choose style options. Commit the project lockfile so teammates and CI use the same tool versions. These npm packages are **not** installed by Mason — Mason only supplies editor-side binaries.

## Installation

```sh
git clone <this-repo> ~/.config/nvim
nvim
```

That is the whole procedure. On first launch, in order:

1. `lua/config/lazy.lua` clones lazy.nvim into `~/.local/share/nvim/lazy/` if it is missing.
2. lazy.nvim installs every plugin under `lua/plugins/`, running the `make` build for telescope-fzf-native.
3. nvim-treesitter compiles the parsers listed at the top of `lua/plugins/treesitter.lua`.
4. `mason-tool-installer` runs on `VeryLazy` and installs any missing entry from the list below.

Steps 2 to 4 take a few minutes and run in the background; `:Lazy` and `:Mason` show progress. Restart once they finish.

## Tools installed automatically by mason

Declared in `lua/plugins/mason.lua`, installed into `~/.local/share/nvim/mason/bin`, which `lua/halsten/lsp.lua` prepends to `$PATH` so the bare `cmd = { "name" }` in each `lsp/<name>.lua` resolves. Refresh them with `:MasonToolsUpdate`.

| Tool | Role | Needs |
| --- | --- | --- |
| `gopls` | Go LSP — staticcheck and the extra analyses are configured in `lsp/gopls.lua` | Go |
| `goimports` | Go formatter, wired into conform | Go |
| `gofumpt` | installed but deliberately **not** used for formatting — see the comment in `lua/plugins/conform.lua` | Go |
| `golangci-lint` | installed for command-line use; nothing in the config invokes it | Go |
| `delve` | the Go debug adapter behind nvim-dap | Go |
| `templ` | one binary serving as both LSP (`templ lsp`) and formatter (`templ fmt`) for `.templ` | Go |
| `lua-language-server` | Lua LSP | — |
| `stylua` | Lua formatter | — |
| `bash-language-server` | shell LSP | **node + npm** |
| `shfmt` | shell formatter | — |
| `shellcheck` | shell linter | — |
| `typescript-language-server` | TS/JS/TSX/JSX LSP, including SolidJS; bundles a fallback TypeScript compiler | **node + npm** |
| `eslint-lsp` | ESLint diagnostics and code actions (`vscode-eslint-language-server`); uses project-local ESLint and rules | **node + npm**, project ESLint config/dependencies |
| `prettier` | TS/JS/TSX/JSX, CSS/SCSS, HTML, JSON/JSONC and YAML formatter | **node + npm** |
| `marksman` | markdown LSP: links, references, outline. Does no formatting | — |
| `rumdl` | markdown formatter — fixes markdownlint rule violations and never reflows paragraphs, which is what `after/ftplugin/markdown.lua` leaves `textwidth` at 0 for |  |
| `sqlfmt` | SQL formatter, wired into conform | **python3** (mason builds it a venv) |
| `taplo` | TOML LSP *and* formatter from one binary — here for `Cargo.toml` | — |
| `codelldb` | the Rust debug adapter behind nvim-dap | — |

Not in that list, on purpose: **`rust-analyzer`** and **`rustfmt`** are rustup components rather than mason packages — see [Rust](#rust) for why installing them through mason actively breaks proc-macro expansion.

## External CLIs the config shells out to

These are not managed by mason; they must be on `$PATH` yourself.

| Binary | Used by | Behaviour when missing |
| --- | --- | --- |
| `rg` | telescope `live_grep`, `grep_string`; grug-far | grep pickers cannot run at all |
| `fd` | telescope `find_files` | falls back to `rg --files`, then `find` — slower, and honours `.gitignore` differently |
| `lazygit` | `<leader>gg`, `<leader>gf` — `lua/halsten/lazygit.lua` | reports "lazygit not found in $PATH" |
| `codex` | `<leader>ai`, `<leader>aI` — `lua/halsten/codex.lua` | reports "codex: not on PATH" |

`codex` is OpenAI's Codex CLI, installed separately. Sign in with `codex login` and ensure `codex` is on `$PATH`. This integration targets CLI 0.153.4 or newer.

- `<leader>ai` asks for code using the enclosing function as context (with a nearby-lines fallback).
- `<leader>aI` sends the whole buffer as context.
- Both run in the background, show an inline spinner, and insert the answer at a tracked cursor position with matching indentation, even after switching buffers or editing above it.
- The completion notification shows tokens used (input + output), with input, output, and cached input counts. Cached tokens are already included in input. If the CLI omits usage, the notification shows `Tokens used: unavailable`.
- `:CodexCancel` cancels all pending requests. `:ClaudeCancel` remains an alias.

Requests time out after 120 seconds. They use [`codex exec`](https://developers.openai.com/codex/noninteractive) with ephemeral sessions and a read-only sandbox, from an empty temporary directory. Personal CLI configuration, project instructions, plugins, hooks, and the listed tool features are skipped for these code fills; authentication still uses your normal Codex login. The CLI default model is used; set `opts.model` in `lua/halsten/codex.lua` to select another model.

## Optional extras

### French spell file

`after/ftplugin/markdown.lua` sets `spelllang=en_us,fr`, so a word is accepted if it exists in either dictionary. Neovim ships only `en`, and offers to download `fr.utf-8.spl` into `~/.local/share/nvim/site/spell/` the first time you open a markdown buffer. Accept the prompt once and it is permanent. Declining leaves every French word underlined.

### `godbg` shell function

The **Connect to godbg** entry in `lua/plugins/dap.lua` expects a headless delve listening on `127.0.0.1:2345`, and the **Attach to this project** entry filters the process list for binaries under `/tmp/dlv-`. Both are produced by a `godbg` shell function that lives in `~/.zshrc`, not in this repository: it builds the current module with `-gcflags="all=-N -l"` to `/tmp/dlv-<module>`, then execs `dlv exec --headless --listen=127.0.0.1:2345 --accept-multiclient --continue=false`.

Because delve halts before `main`, breakpoints in `init()` and the first lines of `main()` are reachable — attaching to an already-running process is always too late for those. The function needs `dlv` (mason installs it as `delve`) and `ss` from `iproute2` for its port-in-use check. Without the shell function, plain `<leader>dc` still works through nvim-dap-go's own launch configurations.

### Debugging Rust

Nothing extra to install and no shell function involved — `codelldb` comes from mason and `lua/plugins/dap.lua` writes the adapter and the one launch configuration itself, since there is no nvim-dap-rust doing for Rust what nvim-dap-go does for Go.

`<leader>dc` in a Rust buffer runs **Build and launch a binary**: it shells out to `cargo build` first (a failure aborts the session and reports the compiler output rather than launching a stale binary from `target/debug`), then prompts for which executable to run — a crate can produce several, `src/main.rs` plus anything under `src/bin/`. The config sets `sourceLanguages = { "rust" }`, which is what enables codelldb's Rust visualisers; without it a `String` inspects as a struct of pointer, length and capacity and a `Vec<T>` as raw memory.

The debug profile is used deliberately. `cargo build --release` strips debug info and inlines aggressively, so breakpoints in small functions are never hit.

## Verifying an install

```vim
:checkhealth                   " full report; the mason section lists missing runtimes
:checkhealth nvim-treesitter   " parser status and compiler detection
:Lazy                          " plugin status
:Mason                         " installed tool binaries
:MasonToolsUpdate              " (re)install anything missing from the list above
:ConformInfo                   " which formatter will run in the current buffer
```

Note that on the `main` branch of nvim-treesitter the old `:TSInstallInfo` is gone; the commands are `:TSInstall`, `:TSUpdate`, `:TSUninstall` and `:TSLog`.

A couple of Rust-specific checks:

```sh
rustup component list --installed   # rust-analyzer and rust-src must both appear
rust-analyzer --version             # empty output means ~/.cargo/bin is not on your shell PATH
```

Neovim finds `rust-analyzer` regardless of that second one — `lua/halsten/lsp.lua` appends `~/.cargo/bin` itself — so check `:checkhealth vim.lsp` for the attached client if you want the editor's own answer.

For SolidJS, after installing Node/npm, run `:MasonToolsInstall` and wait for `typescript-language-server`, `eslint-lsp` and `prettier` to finish, then restart Neovim. Open a project `.tsx` file:

```vim
:set filetype?                 " typescriptreact (javascriptreact for .jsx)
:checkhealth vim.lsp            " ts_ls; also eslint when the project has a config
:ConformInfo                   " prettier should be available
```

`gd` jumps to definitions, `K` shows hover, `<leader>ar` renames, `<leader>ao` organizes imports, and `<leader>ac` offers code actions / ESLint fixes. Save to format, or use `<leader>af`. From the project directory, `npx eslint src` checks linting and `npx tsc --noEmit -p tsconfig.app.json` checks types (use `tsconfig.json` instead if that is the source config).

`:checkhealth` will always warn about the runtimes this config does not use — luarocks, ruby, gem, composer, php, julia. Those are safe to ignore. Act on missing `node`/`npm` for SolidJS / TS / JS tooling or shell LSP.

## Known gaps on this machine

- `gofumpt` and `golangci-lint` are installed but not wired into anything; conform formats Go with `goimports` alone, on purpose.
- `sqlfmt` parses SQL rather than just shuffling whitespace, so it refuses a file whose dialect it cannot read — the error surfaces in `:ConformInfo` / `:messages` and the buffer is left untouched rather than mangled. Standard ANSI, Postgres and dbt-flavoured SQL are fine; exotic vendor DDL may not be.
- Nothing provides SQL completion or diagnostics — `sqlfmt` is a formatter only, and no SQL LSP is enabled. `sqls` would need a live database connection configured per project, which is not worth it here.
