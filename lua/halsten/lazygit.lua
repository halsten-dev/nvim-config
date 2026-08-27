-- Lazygit in a floating terminal.
--
-- No plugin: a scratch buffer, a float over the whole editor, and `jobstart`
-- with `term = true` turning that buffer into a terminal. The float is closed
-- and the buffer wiped the moment lazygit exits, so it behaves like a modal
-- rather than leaving a stray terminal buffer in the buffer list.

local M = {}

-- One float at a time. Pressing the map again while lazygit is up jumps back to
-- the window instead of starting a second copy against the same repo -- two
-- lazygits on one worktree fight over the index lock.
local state = { win = nil, buf = nil }

-- Files on disk change under us while lazygit runs (checkout, stash, reset,
-- discard). Reload the buffers that Neovim already has open so what's on screen
-- matches the worktree.
--
-- `:checktime` only reloads silently when 'autoread' is on; without it every
-- changed buffer stops for a "file changed" prompt. It's off globally (nothing
-- in config.lua sets it), so turn it on just for this call. A buffer with
-- unsaved changes still prompts, which is right -- that one is a real conflict.
local function reload_buffers()
  local autoread = vim.o.autoread
  vim.o.autoread = true
  vim.cmd("checktime")
  vim.o.autoread = autoread
end

-- Where to start lazygit. `path` nil means the editor's cwd; pass a file and it
-- opens the repo that file belongs to, which is the one you want when a session
-- has buffers from more than one worktree.
--
-- vim.fs.root walks up looking for .git -- a file, not just a directory, so
-- worktrees and submodules resolve too. Falling back to cwd rather than
-- refusing keeps the map useful in a fresh directory: lazygit itself offers to
-- `git init` there.
local function repo_root(path)
  if not path or path == "" then
    return vim.fn.getcwd()
  end
  return vim.fs.root(path, ".git") or vim.fn.getcwd()
end

local function close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
  state.win, state.buf = nil, nil
end

local function open(cwd)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    vim.cmd("startinsert")
    return
  end

  if vim.fn.executable("lazygit") == 0 then
    vim.notify("lazygit not found in $PATH", vim.log.levels.ERROR)
    return
  end

  -- Scratch, unlisted: it must not show up in the bufferline or in <leader>bb.
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.92)
  local height = math.floor(vim.o.lines * 0.92)

  -- No `border` key on purpose -- 'winborder' is "rounded" globally
  -- (lua/halsten/config.lua), so leaving it out inherits that.
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    title = " lazygit ",
    title_pos = "center",
  })

  state.win, state.buf = win, buf

  -- jobstart turns the *current* buffer into the terminal, which is why the
  -- window is opened (and focused) first. on_exit runs in a fast context where
  -- window and buffer calls aren't allowed, hence schedule().
  vim.fn.jobstart({ "lazygit" }, {
    cwd = cwd,
    term = true,
    on_exit = function()
      vim.schedule(function()
        close()
        reload_buffers()
      end)
    end,
  })

  vim.cmd("startinsert")
end

-- Lazygit on the editor's cwd.
function M.open()
  open(repo_root(nil))
end

-- Lazygit on the repo containing the current file.
function M.open_current_file()
  open(repo_root(vim.api.nvim_buf_get_name(0)))
end

return M
