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

        -- Indentation (upstream marks this experimental)
        vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"

        -- Folding
        vim.wo[0][0].foldmethod = "expr"
        vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
      end,
    })
  end,
}
