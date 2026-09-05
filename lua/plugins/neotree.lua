-- Neo-tree opens as a full-height split on the far left, and Vim funds that new
-- window by shrinking its neighbours -- by default every window gives up a
-- slice, so an existing vsplit loses the width you gave it. 'winfixwidth' makes
-- a window refuse automatic resizing, so pinning everything except the
-- rightmost window puts the whole cost on that one window and leaves the others
-- alone. The pins are lifted right after, so manual <C-Left>/<C-Right> resizes
-- keep working.
--
-- Same trick on the way out: closing gives the freed columns back to the
-- rightmost window instead of re-spreading them.
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
          keep_widths(function()
            require("neo-tree.command").execute({ toggle = true, dir = vim.uv.cwd() })
          end)
        end,
        desc = "Explorer (toggle)",
      },
    },
    opts = {
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
