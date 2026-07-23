-- Debugging. nvim-dap speaks the Debug Adapter Protocol; delve (dlv) is the
-- Go adapter, and nvim-dap-go writes the delve config + the Go-specific
-- launch configurations for you.
return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      { "leoluz/nvim-dap-go", opts = {} },
      {
        "rcarriga/nvim-dap-ui",
        dependencies = { "nvim-neotest/nvim-nio" },
        opts = {},
      },
    },
    -- Loaded by the <leader>d* maps in lua/halsten/remap.lua.
    lazy = true,
    config = function()
      local dap, dapui = require("dap"), require("dapui")

      -- Open the UI when a session starts, close it when the session ends.
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end

      vim.fn.sign_define("DapBreakpoint", { text = "B", texthl = "DiagnosticSignError" })
      vim.fn.sign_define("DapStopped", { text = ">", texthl = "DiagnosticSignWarn", linehl = "Visual" })
    end,
  },
}
