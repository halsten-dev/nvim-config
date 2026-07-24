-- LSP progress spinner state, driven by the LspProgress autocmd. A libuv timer
-- animates the frames while work is in flight and stops itself when it ends.
local uv = vim.uv or vim.loop
local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local state = { running = false, idx = 1, msg = "" }
local timer = nil

local function refresh()
  if package.loaded["lualine"] then
    require("lualine").refresh()
  end
end

local function ensure_timer()
  if timer then
    return
  end
  timer = uv.new_timer()
  timer:start(0, 100, vim.schedule_wrap(function()
    if state.running then
      state.idx = state.idx % #spinner + 1
      refresh()
    elseif timer then
      timer:stop()
      timer:close()
      timer = nil
    end
  end))
end

vim.api.nvim_create_autocmd("LspProgress", {
  group = vim.api.nvim_create_augroup("halsten_lsp_progress", { clear = true }),
  callback = function(args)
    local val = args.data and args.data.params and args.data.params.value
    if not val or not val.kind then
      return
    end
    if val.kind == "end" then
      state.running = false
      state.msg = ""
    else
      state.running = true
      state.msg = val.title or ""
      ensure_timer()
    end
    refresh()
  end,
})

return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  event = "VeryLazy",
  opts = {
    options = {
      theme = "gruvbox",
      -- One statusline shared by every window (sets laststatus=3).
      globalstatus = true,
      -- Powerline separators; need a Nerd Font (you already use one via devicons).
      section_separators = { left = "", right = "" },
      component_separators = { left = "", right = "" },
    },
    sections = {
      lualine_a = { "mode" },
      lualine_b = { "branch", "diff", "diagnostics" },
      lualine_c = { { "filename", path = 1 } }, -- path=1: show relative path
      lualine_x = {
        -- LSP progress spinner: shows while a server is indexing/loading.
        {
          function()
            return spinner[state.idx] .. " " .. state.msg
          end,
          cond = function()
            return state.running
          end,
        },
        -- Active LSP server(s) for the current buffer.
        {
          function()
            local names = {}
            for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
              names[#names + 1] = client.name
            end
            return " " .. table.concat(names, ",")
          end,
          cond = function()
            return next(vim.lsp.get_clients({ bufnr = 0 })) ~= nil
          end,
        },
        "filetype",
      },
      lualine_y = { "progress" },
      lualine_z = { "location" },
    },
  },
}
