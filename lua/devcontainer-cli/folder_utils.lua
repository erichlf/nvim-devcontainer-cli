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

local M = {}

-- return true if directory exists
local function _directory_exists(target_folder)
  return (vim.fn.isdirectory(target_folder) == 1)
end

-- get the devcontainer path for the given directory
---@param directory (string) the directory containing .devcontainer
---@return (string|nil) directory if a devcontainer exists within it or nil otherwise
local function _get_devcontainer_parent(directory)
  local devcontainer_directory = directory .. '/.devcontainer'

  if _directory_exists(devcontainer_directory) then
    return directory
  end

  return nil
end

-- get the root directory the devcontainer given a directory
---@param directory (string) to begin search in
---@param toplevel (boolean) flag indicating if the directory closes to root should be
-- returned
---@return (string|nil) the devcontainer directory closest to the root directory
-- or the first if toplevel is true, and nil if no directory was found
local function _get_root_directory(directory, toplevel)
  local parent_directory = vim.fn.fnamemodify(directory, ':h')
  local devcontainer_parent = _get_devcontainer_parent(directory)

  -- Base case: If we've reached the root directory
  if parent_directory == directory then
    return devcontainer_parent
  end

  if not toplevel and devcontainer_parent ~= nil then
    return devcontainer_parent
  end

  local upper_devcontainer_directory = _get_root_directory(parent_directory, toplevel)
  -- no devcontainer higher up so return what was found here
  if upper_devcontainer_directory == nil then
    return devcontainer_parent
  end

  -- return the highest level devcontainer
  return upper_devcontainer_directory
end

-- find the .devcontainer directory closes to the root upward from the current
-- directory
---@param toplevel (boolean) flag indicating if the directory closes to root should be
-- returned
---@return (string|nil) the devcontainer directory closest to the root directory
-- or the first if toplevel is true, and nil if no directory was found
function M.get_root(toplevel)
  local current_directory = vim.fn.getcwd()
  return _get_root_directory(current_directory, toplevel)
end

return M
