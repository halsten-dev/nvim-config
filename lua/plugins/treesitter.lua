-- nvim-treesitter `main` branch: setup() only accepts `install_dir`.
-- Parsers are installed via install(), and highlight/indent/folds are enabled
-- per-buffer by Neovim itself -- none of it happens automatically.

local ensure_installed = {
  "bash",
  "c",
  "diff",
  "go",
  "gomod",
  "gosum",
  "gowork",
  "gotmpl",
  "html",
  "javascript",
  "jsdoc",
  "json",
  "lua",
  "luadoc",
  "luap",
  "markdown",
  "markdown_inline",
  "printf",
  "python",
  "query",
  "regex",
  "ron",
  "rust",
  "sql",
  "templ",
  "toml",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
  "xml",
  "yaml",
}

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false, -- this plugin does not support lazy-loading
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").install(ensure_installed)

    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("halsten_treesitter", { clear = true }),
      callback = function(ev)
        local lang = vim.treesitter.language.get_lang(ev.match)
        if not lang or not pcall(vim.treesitter.start, ev.buf, lang) then
          return
        end

        -- Indentation. Treesitter's indent is upstream-experimental and, on the
        -- `main` branch, parses asynchronously -- on a cold or lagging buffer it
        -- computes from a stale tree and returns the parent line's indent, so a
        -- new line after `{` lands under-indented. Neovim's native ftplugin
        -- indent (Go, C, Python, Lua, ...) is synchronous and correct, and runs
        -- on this same FileType event *before* us. So only reach for treesitter
        -- indent when the filetype shipped no indentexpr of its own.
        if vim.bo[ev.buf].indentexpr == "" then
          vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end

        -- Folding
        vim.wo[0][0].foldmethod = "expr"
        vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
      end,
    })
  end,
}
