-- Copyright (c) 2024 Erich L Foster
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

local config           = require("devcontainer-cli.config")
local folder_utils     = require("devcontainer-cli.folder_utils")
local Terminal         = require('toggleterm.terminal').Terminal
local mode             = require('toggleterm.terminal').mode

local M                = {}

-- valid window directions
local directions = {
  "float",
  "horizontal",
  "tab",
  "vertical",
}

-- window management variables
local _terminal        = nil
--
-- number of columns for displaying text
local terminal_columns = config.terminal_columns

-- wrap the given text at max_width
---@param text (string) the text to wrap
---@return (string) the text wrapped
local function _wrap_text(text)
  local wrapped_lines = {}
  for line in text:gmatch("[^\n]+") do
    local current_line = ""
    for word in line:gmatch("%S+") do
      if #current_line + #word <= terminal_columns then
        current_line = current_line .. word .. " "
      else
        table.insert(wrapped_lines, current_line)
        current_line = word .. " "
      end
    end
    table.insert(wrapped_lines, current_line)
  end
  return table.concat(wrapped_lines, "\n")
end

-- window the created window detaches set things back to -1
local _on_detach = function()
  _terminal = nil
end

-- on_fail callback
---@param exit_code (number) the exit code from the failed job
local _on_fail = function(exit_code)
  vim.notify(
    "Devcontainer process has failed! exit_code: " .. exit_code,
    vim.log.levels.ERROR
  )

  vim.cmd("silent! :checktime")
end

local _on_success = function()
  vim.notify("Devcontainer process succeeded!", vim.log.levels.INFO)
end

-- on_exit callback function to delete the open buffer when devcontainer exits
-- in a neovim terminal
---@param code (number) the exit code
local _on_exit = function(code)
  if code == 0 then
    _on_success()
    return
  end

  _on_fail(code)
end

-- check if the value is in the given table
local function tableContains(tbl, value)
  for _, item in ipairs(tbl) do
    if item == value then
      return true
    end
  end

  return false
end

---@class ParsedArgs
---@field direction string?
---@field cmd string?
---@field size number?

---Take a users command arguments in the format "cmd='git commit' direction='float'" size='42'
---and parse this into a table of arguments
---{cmd = "git commit", direction = "float", size = "42"}
---@param args string
---@return ParsedArgs
function M.parse(args)
  local p = {
    single = "'(.-)'",
    double = '"(.-)"',
  }
  local result = {}
  if args then
    local quotes = args:match(p.single) and p.single or args:match(p.double) and p.double or nil
    if quotes then
      -- 1. extract the quoted command
      local pattern = "(%S+)=" .. quotes
      for key, value in args:gmatch(pattern) do
        quotes = p.single
        value = vim.fn.shellescape(value)
        result[vim.trim(key)] = vim.fn.expandcmd(value:match(quotes))
      end
      -- 2. then remove it from the rest of the argument string
      args = args:gsub(pattern, "")
    end

    for _, part in ipairs(vim.split(args, " ")) do
      if #part > 1 then
        local arg = vim.split(part, "=")
        local key, value = arg[1], arg[2]
        if key == "size" then
          value = tonumber(value)
        end
        result[key] = value
      end
    end
  end
  return result
end

-- build the initial part of a devcontainer command
---@param action (string) the action for the devcontainer to perform
-- (see man devcontainer)
---@return (string|nil) nil if no devcontainer_parent could be found otherwise
-- the basic devcontainer command for the given type
local function _devcontainer_command(action)
  local devcontainer_root = folder_utils.get_root(config.toplevel)
  if devcontainer_root == nil then
    vim.notify("Unable to find devcontainer directory...", vim.log.levels.ERROR)
    return nil
  end

  local command = "devcontainer " .. action
  command = command .. " --workspace-folder '" .. devcontainer_root .. "'"

  return command
end

-- helper function to generate devcontainer bringup command
---@return (string|nil) nil if no devcontainer_parent could be found otherwise the
-- devcontainer bringup command
local function _get_devcontainer_up_cmd()
  local command = _devcontainer_command("up")
  if command == nil then
    return command
  end

  if config.remove_existing_container then
    command = command .. " --remove-existing-container"
  end
  command = command .. " --update-remote-user-uid-default off"

  if config.dotfiles_repository == "" or config.dotfiles_repository == nil then
    return command
  end

  command = command .. " --dotfiles-repository '" .. config.dotfiles_repository
  -- only include the branch if it exists
  if config.dotfiles_branch ~= "" and config.dotfiles_branch ~= nil then
    command = command .. " -b " .. config.dotfiles_branch
  end
  command = command .. "'"

  if config.dotfiles_targetPath ~= "" and config.dotfiles_targetPath ~= nil then
    command = command .. " --dotfiles-target-path '" .. config.dotfiles_targetPath .. "'"
  end

  if config.dotfiles_install_command ~= "" and config.dotfiles_install_command ~= nil then
    command = command .. " --dotfiles-install-command '" .. config.dotfiles_install_command .. "'"
  end

  return command
end

-- create a new window and execute the given command
---@param cmd (string) the command to execute in the devcontainer terminal
---@param direction (string|nil) the placement of the window to be created (float, horizontal, vertical)
---@param size (number|nil) the size of the window to be created 
local function _spawn_and_execute(cmd, direction, size)
  direction = vim.F.if_nil(direction, "float")
  if tableContains(directions, direction) == false then
    vim.notify("Invalid direction: " .. direction, vim.log.levels.ERROR)
    return
  end

  -- create the terminal
  _terminal = Terminal:new {
    cmd = cmd,
    hidden = false,
    display_name = "devcontainer-cli",
    direction = vim.F.if_nil(direction, "float"),
    dir = folder_utils.get_root(config.toplevel),
    size = size,
    close_on_exit = false,
    on_open = function(term)
      -- ensure that we are not in insert mode
      vim.cmd("stopinsert")
      vim.api.nvim_buf_set_keymap(
        term.bufnr,
        'n',
        '<esc>',
        '<CMD>lua vim.api.nvim_buf_delete(' .. term.bufnr .. ', { force = true } )<CR><CMD>close<CR>',
        { noremap = true, silent = true }
      )
      vim.api.nvim_buf_set_keymap(
        term.bufnr,
        'n',
        'q',
        '<CMD>lua vim.api.nvim_buf_delete(' .. term.bufnr .. ', { force = true } )<CR><CMD>close<CR>',
        { noremap = true, silent = true }
      )
      vim.api.nvim_buf_set_keymap(term.bufnr, 'n', 't', '<CMD>close<CR>', { noremap = true, silent = true })
    end,
    auto_scroll = true,
    on_exit = function(_, _, code, _)
      _on_exit(code)
      _on_detach()
    end, -- callback for when process closes
  }
  -- start in insert mode
  _terminal:set_mode(mode.NORMAL)
  -- now execute the command
  _terminal:open()
end

-- issues command to bringup devcontainer
function M.bringup()
  local command = _get_devcontainer_up_cmd()

  if command == nil then
    return
  end

  if config.interactive then
    vim.ui.input(
      {
        prompt = _wrap_text(
          "Spawning devcontainer with command: " .. command
        ) .. "\n\n" .. "Press q to cancel or any other key to continue\n"
      },
      function(input)
        if (input == "q" or input == "Q") then
          vim.notify(
            "\nUser cancelled bringing up devcontainer"
          )
        else
          _spawn_and_execute(command)
        end
      end
    )
    return
  end

  _spawn_and_execute(command)
end

-- execute the given cmd within the given devcontainer_parent
---@param cmd (string) the command to issue in the devcontainer terminal
---@param direction (string|nil) the placement of the window to be created
-- (left, right, bottom, float)
function M._exec_cmd(cmd, direction, size)
  local command = _devcontainer_command("exec")
  if command == nil then
    return
  end

  command = command .. " " .. config.shell .. " -c '" .. cmd .. "'"
  vim.notify(command)
  _spawn_and_execute(command, direction, size)
end

-- execute a given cmd within the given devcontainer_parent
---@param cmd (string|nil) the command to issue in the devcontainer terminal
---@param direction (string|nil) the placement of the window to be created
-- (left, right, bottom, float)
---@param size (number|nil) size of the window to create
function M.exec(cmd, direction, size)
  if _terminal ~= nil then
    vim.notify("There is already a devcontainer process running.", vim.log.levels.WARN)
    return
  end

  if cmd == nil or cmd == "" then
    vim.ui.input(
      { prompt = "Enter command:" },
      function(input)
        if input ~= nil then
          M._exec_cmd(input, direction, size)
        else
          vim.notify("No command received, ignoring.", vim.log.levels.WARN)
        end
      end
    )
  else
    M._exec_cmd(cmd, direction, size)
  end
end

-- toggle the current terminal
function M.toggle()
  if _terminal == nil then
    vim.notify("No devcontainer window to toggle.", vim.log.levels.WARN)
    return
  end
  _terminal:toggle()
end

return M
