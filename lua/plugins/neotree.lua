return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    cmd = "Neotree",
    keys = {
	    {
		    "<leader>e",
		    function()
			    require("neo-tree.command").execute({toggle = true, dir = vim.uv.cwd() })
		    end,
		    desc = "Explorer",
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
