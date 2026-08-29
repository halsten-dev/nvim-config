# nvim

Personal Neovim configuration: Go, templ, Lua, shell and markdown, built on Neovim's own LSP client. lazy.nvim manages plugins, mason manages the external tool binaries, and there is no distribution layer in between — every plugin spec in `lua/plugins/` and every server definition in `lsp/` is hand-written and commented with the reasoning behind it.

## Requirements at a glance

| Layer | What | Required? |
| --- | --- | --- |
| Editor | Neovim ≥ 0.11 | yes |
| Build | `base-devel` (make + gcc), `git`, `curl`, `unzip`, `tar`, `gzip` | yes |
| Runtime | Go toolchain | yes — mason builds the Go tooling with it |
| Runtime | Node + npm | optional — only `bash-language-server` needs it |
| Search | `ripgrep`, `fd` | yes in practice — telescope and grug-far depend on them |
| Git UI | `lazygit` | optional — `<leader>gg` / `<leader>gf` are dead without it |
| AI | `claude` CLI | optional — `<leader>ai` / `<leader>aI` are dead without it |
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
| `go` | the Go toolchain, and what mason uses to build most of the Go tooling |
| `tree-sitter-cli` | recommended for the nvim-treesitter `main` branch when a grammar has to be generated rather than downloaded |
| `lazygit` | the `<leader>gg` / `<leader>gf` float in `lua/halsten/lazygit.lua` |
| a Nerd Font | `ttf-hack-nerd` or similar — see below |

Install the lot:

```sh
sudo pacman -S --needed neovim git base-devel curl wget unzip \
  ripgrep fd go tree-sitter-cli lazygit ttf-hack-nerd
```

On Debian or Ubuntu the equivalents are `build-essential` for `base-devel` and `fd-find` for `fd` — note that the latter installs the binary as `fdfind`, so symlink it to `fd` somewhere on `$PATH` or telescope will not find it. Neovim's repository versions are frequently older than 0.11; prefer the official AppImage or a source build there.

### Fonts

A Nerd Font is not decorative here. `nvim-web-devicons` feeds bufferline, lualine, neo-tree and render-markdown; blink is configured with `nerd_font_variant = "mono"`; and lualine draws powerline separators. Without one you get replacement boxes across the whole UI. Any patched font works — this machine has `ttf-hack-nerd` and `ttf-meslo-nerd-font-powerlevel10k`. Set it in your terminal emulator, not in Neovim.

## Language runtimes

**Go** is required. Mason builds `gopls`, `goimports`, `gofumpt`, `golangci-lint`, `delve` and `templ` with the Go toolchain, so without it most of the tool list below silently fails to install.

**Node and npm** are optional and currently **not installed on this machine**. Exactly one declared tool needs them: `bash-language-server`. Until node is present, `vim.lsp.enable("bashls")` in `lua/halsten/lsp.lua` will keep failing quietly and shell buffers get no LSP — `shfmt` formatting and `shellcheck` are unaffected, since both are standalone binaries. To close that gap:

```sh
sudo pacman -S nodejs npm
```

Nothing else in the config needs a Python, Ruby, PHP, Java or Rust toolchain. The Rust pieces — blink.cmp's fuzzy matcher and the `rumdl` markdown formatter — both ship prebuilt binaries, so no `cargo` is required.

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
| `marksman` | markdown LSP: links, references, outline. Does no formatting | — |
| `rumdl` | markdown formatter — fixes markdownlint rule violations and never reflows paragraphs, which is what `after/ftplugin/markdown.lua` leaves `textwidth` at 0 for | — |

## External CLIs the config shells out to

These are not managed by mason; they must be on `$PATH` yourself.

| Binary | Used by | Behaviour when missing |
| --- | --- | --- |
| `rg` | telescope `live_grep`, `grep_string`; grug-far | grep pickers cannot run at all |
| `fd` | telescope `find_files` | falls back to `rg --files`, then `find` — slower, and honours `.gitignore` differently |
| `lazygit` | `<leader>gg`, `<leader>gf` — `lua/halsten/lazygit.lua` | reports "lazygit not found in $PATH" |
| `claude` | `<leader>ai`, `<leader>aI` — `lua/halsten/claude.lua` | reports "claude: not on PATH" |

`claude` is Anthropic's Claude Code CLI, installed separately; the config only requires that a binary called `claude` is reachable. On this machine it lives at `~/.local/bin/claude`.

## Optional extras

### French spell file

`after/ftplugin/markdown.lua` sets `spelllang=en_us,fr`, so a word is accepted if it exists in either dictionary. Neovim ships only `en`, and offers to download `fr.utf-8.spl` into `~/.local/share/nvim/site/spell/` the first time you open a markdown buffer. Accept the prompt once and it is permanent. Declining leaves every French word underlined.

### `godbg` shell function

The **Connect to godbg** entry in `lua/plugins/dap.lua` expects a headless delve listening on `127.0.0.1:2345`, and the **Attach to this project** entry filters the process list for binaries under `/tmp/dlv-`. Both are produced by a `godbg` shell function that lives in `~/.zshrc`, not in this repository: it builds the current module with `-gcflags="all=-N -l"` to `/tmp/dlv-<module>`, then execs `dlv exec --headless --listen=127.0.0.1:2345 --accept-multiclient --continue=false`.

Because delve halts before `main`, breakpoints in `init()` and the first lines of `main()` are reachable — attaching to an already-running process is always too late for those. The function needs `dlv` (mason installs it as `delve`) and `ss` from `iproute2` for its port-in-use check. Without the shell function, plain `<leader>dc` still works through nvim-dap-go's own launch configurations.

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

`:checkhealth` will always warn about the runtimes this config does not use — cargo, luarocks, ruby, gem, composer, php, julia. Those are safe to ignore. The one worth acting on is `node`/`npm`, and only if you want shell LSP.

## Known gaps on this machine

- **No node or npm**, so `bash-language-server` cannot be installed and `bashls` never attaches. Every other declared tool is reachable without it.
- `gofumpt` and `golangci-lint` are installed but not wired into anything; conform formats Go with `goimports` alone, on purpose.
