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

      -- Attaching to an already-running binary is how you debug a TUI: the app
      -- keeps its own terminal instead of fighting Neovim for this one.
      table.insert(dap.configurations.go, 1, {
        type = "go",
        name = "Attach to this project",
        request = "attach",
        mode = "local",
        processId = function()
          local utils = require("dap.utils")

          -- Match on a fixed marker rather than guessing the binary's name.
          -- The `godbg` shell function builds to /tmp/dlv-<module>, so any
          -- process started that way is a debug build and nothing else is.
          -- Deriving a name from go.mod instead meant the shell and this file
          -- had to agree on the derivation, and they kept disagreeing.
          local function match(proc)
            return proc.name:find("/tmp/dlv-", 1, true) ~= nil
          end

          -- Only narrow the list if a debug build is actually running --
          -- otherwise an empty list would abort the run. The fallback is
          -- fuzzy-searchable via telescope-ui-select.
          local opts = {}
          if #utils.get_processes({ filter = match }) > 0 then
            opts.filter = match
          end
          return utils.pick_process(opts)
        end,
      })

      -- The `godbg` shell function now runs the binary under a headless delve
      -- that blocks until a client connects, so breakpoints in init() or the
      -- first lines of main() are reachable -- attaching to a live process is
      -- always too late for those. nvim-dap-go sees mode = "remote" and dials
      -- the existing server instead of spawning a delve of its own.
      -- First in the list so <leader>dc reaches it in one keypress.
      table.insert(dap.configurations.go, 1, {
        type = "go",
        name = "Connect to godbg",
        request = "attach",
        mode = "remote",
        host = "127.0.0.1",
        port = 2345,
      })

      vim.fn.sign_define("DapBreakpoint", { text = "B", texthl = "DiagnosticSignError" })
      vim.fn.sign_define("DapStopped", { text = ">", texthl = "DiagnosticSignWarn", linehl = "Visual" })
    end,
  },
}
