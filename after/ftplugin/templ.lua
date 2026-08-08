-- `templ fmt` emits hard tabs, same as gofmt. The global config sets expandtab,
-- which would insert spaces that the formatter converts back on every save.
vim.opt_local.expandtab = false
vim.opt_local.tabstop = 4
vim.opt_local.shiftwidth = 4
vim.opt_local.softtabstop = 4
