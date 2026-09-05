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

      -- Rust. There is no nvim-dap-rust writing the adapter and the launch
      -- configurations the way nvim-dap-go does for Go, so both are spelled out
      -- here.
      --
      -- codelldb over the plain `lldb-dap` binary because it ships the Rust
      -- type visualisers: without them a String prints as a struct of pointer,
      -- length and capacity, and a Vec<T> as raw memory. `sourceLanguages`
      -- below is what turns them on.
      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          -- Mason installs codelldb here. halsten/lsp.lua's PATH prepend
          -- happens at startup, but nvim-dap resolves this string itself and
          -- does not go through a shell, so give it the full path.
          command = vim.fn.stdpath("data") .. "/mason/bin/codelldb",
          args = { "--port", "${port}" },
        },
      }

      dap.configurations.rust = {
        {
          name = "Build and launch a binary",
          type = "codelldb",
          request = "launch",
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
          -- Enables codelldb's Rust data formatters (see above).
          sourceLanguages = { "rust" },
          args = {},

          -- codelldb takes a path to an already-compiled binary and will
          -- happily attach to a stale one, which is the most confusing failure
          -- in debugging: breakpoints resolve onto the line numbers of the
          -- source as it was at the last build, so you single-step through code
          -- that is not what you are reading. Build first, every time.
          --
          -- Debug profile, not release: `cargo build --release` strips the
          -- debug info and inlines aggressively, so breakpoints in small
          -- functions are never hit.
          program = function()
            vim.notify("cargo build ...", vim.log.levels.INFO)
            local out = vim.fn.system({ "cargo", "build" })
            if vim.v.shell_error ~= 0 then
              vim.notify(out, vim.log.levels.ERROR, { title = "cargo build failed" })
              -- Returning the sentinel aborts the session cleanly rather than
              -- launching against whatever binary is left in target/debug.
              return require("dap").ABORT
            end

            -- A crate can produce several binaries (src/main.rs plus anything
            -- under src/bin/), so which one still has to be chosen. Completion
            -- is rooted at target/debug, and the directory also holds the .d
            -- files and build/ -- the executables are the extensionless ones.
            return vim.fn.input("Executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
          end,
        },
      }

      vim.fn.sign_define("DapBreakpoint", { text = "B", texthl = "DiagnosticSignError" })
      vim.fn.sign_define("DapStopped", { text = ">", texthl = "DiagnosticSignWarn", linehl = "Visual" })
    end,
  },
}
