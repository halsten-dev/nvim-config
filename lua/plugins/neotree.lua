-- Neo-tree opens as a full-height split on the far left, and Vim funds that new
-- window by shrinking its neighbours -- by default every window gives up a
-- slice, so an existing vsplit loses the width you gave it. 'winfixwidth' makes
-- a window refuse automatic resizing, so pinning everything except the
-- rightmost window puts the whole cost on that one window and leaves the others
-- alone. The pins are lifted right after, so manual <C-Left>/<C-Right> resizes
-- keep working.
local function keep_widths(fn)
  local wins = vim.tbl_filter(function(w)
    return vim.api.nvim_win_get_config(w).relative == ""
  end, vim.api.nvim_tabpage_list_wins(0))

  local rightmost, max_col
  for _, w in ipairs(wins) do
    local col = vim.api.nvim_win_get_position(w)[2]
    if not max_col or col > max_col then
      max_col, rightmost = col, w
    end
  end

  local saved = {}
  for _, w in ipairs(wins) do
    if w ~= rightmost then
      saved[w] = vim.wo[w].winfixwidth
      vim.wo[w].winfixwidth = true
    end
  end

  fn()

  -- Deferred: neo-tree's open is async, so the window doesn't exist yet when
  -- execute() returns and the pins must outlive this call.
  vim.schedule(function()
    for w, old in pairs(saved) do
      if vim.api.nvim_win_is_valid(w) then
        vim.wo[w].winfixwidth = old
      end
    end
  end)
end

-- The neo-tree window in the current tab, if it is already on screen.
local function tree_win()
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(w)
    if vim.bo[buf].filetype == "neo-tree" and vim.api.nvim_win_get_config(w).relative == "" then
      return w
    end
  end
end

-- Shared globs keep test decoration and filtering in sync. Rust unit tests
-- inside src/*.rs cannot be distinguished at the file-explorer level.
local test_globs = {
  "*_test.go",
  "*.test.*",
  "*.spec.*",
  "test_*.py",
  "*_test.py",
  "test",
  "tests",
  "__tests__",
}
local test_patterns
local function get_test_patterns()
  if not test_patterns then
    local glob = require("neo-tree.sources.filesystem.lib.globtopattern")
    test_patterns = vim.tbl_map(glob.globtopattern, test_globs)
  end
  return test_patterns
end

local function is_test(node)
  if node.type ~= "file" and node.type ~= "directory" then
    return false
  end
  for _, pattern in ipairs(get_test_patterns()) do
    if node.name:match(pattern) then
      return true
    end
  end
  return false
end

return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    cmd = "Neotree",
    keys = {
      {
        -- Open-and-focus. When the tree is already up this only jumps to it,
        -- so the key never closes the explorer out from under you.
        "<leader>e",
        function()
          local win = tree_win()
          if win then
            vim.api.nvim_set_current_win(win)
            return
          end
          keep_widths(function()
            require("neo-tree.command").execute({ action = "focus", dir = vim.uv.cwd() })
          end)
        end,
        desc = "Explorer (focus)",
      },
      {
        "<leader>E",
        function()
          if tree_win() then
            -- Closing: spread the freed columns over every remaining window
            -- instead of handing them all to the rightmost one, so a vsplit
            -- comes back to an even 50/50. 'horizontal' keeps heights alone,
            -- and any genuinely pinned ('winfixwidth') sidebar is left as is.
            require("neo-tree.command").execute({ action = "close" })
            vim.schedule(function()
              vim.cmd("horizontal wincmd =")
            end)
          else
            keep_widths(function()
              require("neo-tree.command").execute({ toggle = true, dir = vim.uv.cwd() })
            end)
          end
        end,
        desc = "Explorer (toggle)",
      },
    },
    opts = {
      filesystem = {
        components = {
          icon = function(config, node, state)
            local icon = require("neo-tree.sources.common.components").icon(config, node, state)
            if is_test(node) then
              icon.text = "󰙨"
              icon.highlight = "DiagnosticHint"
            end
            return icon
          end,
          name = function(config, node, state)
            local name = require("neo-tree.sources.common.components").name(config, node, state)
            if node:get_depth() == 1 and node.type == "directory" and state.tests_hidden then
              name.text = name.text .. " [tests hidden]"
            end
            return name
          end,
        },
        commands = {
          toggle_tests = function(state)
            -- Use never_show so H cannot accidentally undo the test filter.
            if not state.tests_hidden then
              state.test_filter_saved = vim.deepcopy(state.filtered_items.never_show_by_pattern or {})
              local patterns = vim.deepcopy(state.test_filter_saved)
              vim.list_extend(patterns, get_test_patterns())
              state.filtered_items.never_show_by_pattern = patterns
            else
              state.filtered_items.never_show_by_pattern = state.test_filter_saved
              state.test_filter_saved = nil
            end
            state.tests_hidden = not state.tests_hidden
            require("neo-tree.sources.filesystem.commands").refresh(state)
          end,
        },
        window = {
          mappings = {
            ["T"] = { "toggle_tests", desc = "Toggle test files" },
          },
        },
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_ignored = false,
          never_show = { ".git" },
        },
      },
      window = {
        mappings = {
          ["t"] = "none",
        },
      },
    },
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons", -- optional, but recommended
    },
    lazy = false, -- neo-tree will lazily load itself
  }
}
