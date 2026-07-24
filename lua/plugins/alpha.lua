return {
  "goolord/alpha-nvim",
  event = "VimEnter",
  config = function()
    local alpha = require("alpha")
    local dashboard = require("alpha.themes.dashboard")

    -- Title: one string per line. Edit / add / remove lines freely.
    -- Replace the placeholder below with your own ASCII art.
    dashboard.section.header.val = {
      [[                                                          ]],
      [[██╗  ██╗ █████╗ ██╗     ███████╗████████╗███████╗███╗   ██╗]],
      [[██║  ██║██╔══██╗██║     ██╔════╝╚══██╔══╝██╔════╝████╗  ██║]],
      [[███████║███████║██║     ███████╗   ██║   █████╗  ██╔██╗ ██║]],
      [[██╔══██║██╔══██║██║     ╚════██║   ██║   ██╔══╝  ██║╚██╗██║]],
      [[██║  ██║██║  ██║███████╗███████║   ██║   ███████╗██║ ╚████║]],
      [[╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═══╝]],
      [[                                                          ]],
    }
    dashboard.section.header.opts.hl = "Type"

    dashboard.section.buttons.val = {
      dashboard.button("f", "  Find files", "<cmd>Telescope find_files<cr>"),
      dashboard.button("e", "  Explorer", "<cmd>Neotree toggle<cr>"),
      dashboard.button("q", "  Quit", "<cmd>qa<cr>"),
    }
    dashboard.section.footer.val = {}
    dashboard.section.footer.opts.hl = "Comment"

    -- Startup time is only final after UIEnter, so fill the footer on VeryLazy
    -- (fires just after) and redraw the dashboard in place.
    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      once = true,
      callback = function()
        local stats = require("lazy").stats()
        local ms = math.floor(stats.startuptime * 100 + 0.5) / 100
        dashboard.section.footer.val =
          "⚡ " .. stats.loaded .. "/" .. stats.count .. " plugins in " .. ms .. " ms"
        pcall(vim.cmd.AlphaRedraw)
      end,
    })

    dashboard.opts.layout = {
      { type = "padding", val = 8 },
      dashboard.section.header,
      { type = "padding", val = 2 },
      dashboard.section.buttons,
      { type = "padding", val = 1 },
      dashboard.section.footer,
    }

    alpha.setup(dashboard.opts)
  end,
}
