return {
	"goolord/alpha-nvim",
	event = "VimEnter",
	config = function()
		local alpha = require("alpha")
		local dashboard = require("alpha.themes.dashboard")

		-- Title: one string per line. Edit / add / remove lines freely.
		-- Replace the placeholder below with your own ASCII art.
		-- dashboard.section.header.val = {
		--   [[                                                          ]],
		--   [[██╗  ██╗ █████╗ ██╗     ███████╗████████╗███████╗███╗   ██╗]],
		--   [[██║  ██║██╔══██╗██║     ██╔════╝╚══██╔══╝██╔════╝████╗  ██║]],
		--   [[███████║███████║██║     ███████╗   ██║   █████╗  ██╔██╗ ██║]],
		--   [[██╔══██║██╔══██║██║     ╚════██║   ██║   ██╔══╝  ██║╚██╗██║]],
		--   [[██║  ██║██║  ██║███████╗███████║   ██║   ███████╗██║ ╚████║]],
		--   [[╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═══╝]],
		--   [[                                                          ]],
		-- }
		-- dashboard.section.header.val = {
		--   [[  __    __       __      ___        ________  ___________  _______  _____  ___  ]],
		--   [[ /" |  | "\     /""\    |"  |      /"       )("     _   ")/"     "|(\"   \|"  \ ]],
		--   [[(:  (__)  :)   /    \   ||  |     (:   \___/  )__/  \\__/(: ______)|.\\   \    |]],
		--   [[ \/      \/   /' /\  \  |:  |      \___  \       \\_ /    \/    |  |: \.   \\  |]],
		--   [[ //  __  \\  //  __'  \  \  |___    __/  \\      |.  |    // ___)_ |.  \    \. |]],
		--   [[(:  (  )  :)/   /  \\  \( \_|:  \  /" \   :)     \:  |   (:      "||    \    \ |]],
		--   [[ \__|  |__/(___/    \___)\_______)(_______/       \__|    \_______) \___|\____\)]],
		--         [[   ]],
		--         [[   ]],
		-- }
		dashboard.section.header.val = {
			[[      :::    :::     :::     :::        :::::::: ::::::::::: :::::::::: ::::    :::]],
			[[     :+:    :+:   :+: :+:   :+:       :+:    :+:    :+:     :+:        :+:+:   :+: ]],
			[[    +:+    +:+  +:+   +:+  +:+       +:+           +:+     +:+        :+:+:+  +:+  ]],
			[[   +#++:++#++ +#++:++#++: +#+       +#++:++#++    +#+     +#++:++#   +#+ +:+ +#+   ]],
			[[  +#+    +#+ +#+     +#+ +#+              +#+    +#+     +#+        +#+  +#+#+#    ]],
			[[ #+#    #+# #+#     #+# #+#       #+#    #+#    #+#     #+#        #+#   #+#+#     ]],
			[[###    ### ###     ### ########## ########     ###     ########## ###    ####      ]],
		}

		dashboard.section.header.opts.hl = "Type"

		-- VIM sub-title as its own element so it centers on its own width instead
		-- of inheriting HALSTEN's left margin. Rendered via a separate layout
		-- entry below with position = "center".
		local vim_title = {
			type = "text",
			val = {
				[[:::     ::: ::::::::::: ::::     ::::]],
				[[:+:     :+:     :+:     +:+:+: :+:+:+]],
				[[+:+     +:+     +:+     +:+ +:+:+ +:+]],
				[[+#+     +:+     +#+     +#+  +:+  +#+]],
				[[ +#+   +#+      +#+     +#+       +#+]],
				[[  #+#+#+#       #+#     #+#       #+#]],
				[[    ###     ########### ###       ###]],
			},
			opts = { position = "center", hl = "Type" },
		}

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
				dashboard.section.footer.val = "⚡ "
					.. stats.loaded
					.. "/"
					.. stats.count
					.. " plugins in "
					.. ms
					.. " ms"
				pcall(vim.cmd.AlphaRedraw)
			end,
		})

		dashboard.opts.layout = {
			{ type = "padding", val = 8 },
			dashboard.section.header,
			{ type = "padding", val = 1 },
			vim_title,
			{ type = "padding", val = 2 },
			{ type = "text", val = "Happy coding session !", opts = { position = "center", hl = "Comment" } },
			{ type = "padding", val = 2 },
			dashboard.section.buttons,
			{ type = "padding", val = 1 },
			dashboard.section.footer,
		}

		alpha.setup(dashboard.opts)
	end,
}
