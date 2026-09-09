-- Mason installs the server, not the project's ESLint library/rules. Only
-- attach in projects with an ESLint config; a fresh unconfigured project
-- should still get TypeScript completion without repeated ESLint errors.
local config_files = {
  "eslint.config.js",
  "eslint.config.mjs",
  "eslint.config.cjs",
  "eslint.config.ts",
  "eslint.config.mts",
  "eslint.config.cts",
  ".eslintrc",
  ".eslintrc.js",
  ".eslintrc.cjs",
  ".eslintrc.json",
  ".eslintrc.yaml",
  ".eslintrc.yml",
}

return {
  cmd = { "vscode-eslint-language-server", "--stdio" },
  filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
  workspace_required = true,
  root_dir = function(bufnr, on_dir)
    local root = vim.fs.root(bufnr, config_files)
    if root then
      on_dir(root)
    end
  end,
  settings = {
    validate = "on",
    useESLintClass = false,
    experimental = {},
    -- Prettier formats on save; ESLint fixes are explicit code actions.
    format = false,
    codeActionOnSave = { enable = false, mode = "all" },
    run = "onType",
    quiet = false,
    onIgnoredFiles = "off",
    rulesCustomizations = {},
    nodePath = "",
    workingDirectory = { mode = "auto" },
    codeAction = {
      disableRuleComment = { enable = true, location = "separateLine" },
      showDocumentation = { enable = true },
    },
  },
  before_init = function(_, config)
    -- vscode-eslint uses this setting as the boundary for config resolution.
    if config.root_dir then
      config.settings.workspaceFolder = {
        uri = vim.uri_from_fname(config.root_dir),
        name = vim.fn.fnamemodify(config.root_dir, ":t"),
      }
    end
  end,
  handlers = {
    ["eslint/openDoc"] = function(_, result)
      if result then
        vim.ui.open(result.url)
      end
      return {}
    end,
    ["eslint/confirmESLintExecution"] = function()
      return 4 -- approved, matching vscode-eslint's execution confirmation protocol
    end,
    ["eslint/probeFailed"] = function()
      vim.notify("ESLint: probing failed; check the project's ESLint config.", vim.log.levels.WARN)
      return {}
    end,
    ["eslint/noLibrary"] = function()
      vim.notify("ESLint: install eslint and its plugins in the project (see README.md).", vim.log.levels.WARN)
      return {}
    end,
    ["eslint/noConfig"] = function()
      vim.notify("ESLint: no usable config found for this file.", vim.log.levels.WARN)
      return {}
    end,
  },
}
