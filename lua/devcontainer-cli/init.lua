local M = {}

local devcontainer_cli = require("devcontainer-cli.devcontainer_cli")
local config = require("devcontainer-cli.config")
local configured = false

-- setup the devcontainer-cli plugin
---@param opts (table) the options to set (see config/init.lua)
function M.setup(opts)
  config.setup(opts)

  if configured then
    print("Already configured, skipping!")
    return
  end

  configured = true

  -- Docker
  vim.api.nvim_create_user_command(
    "DevcontainerUp",
    devcontainer_cli.up,
    {
      nargs = 0,
      desc = "Bringup devcontainer.",
    }
  )

  vim.api.nvim_create_user_command(
    "DevcontainerExec",
    devcontainer_cli.exec,
    {
      nargs = "?",
      desc = "Execute command in devcontainer.",
    }
  )

  vim.api.nvim_create_user_command(
    "DevcontainerToggle",
    devcontainer_cli.toggle,
    {
      nargs = 0,
      desc = "Toggle the current devcontainer window.",
    }
  )

  vim.api.nvim_create_user_command(
    "DevcontainerConnect",
    devcontainer_cli.connect,
    {
      nargs = 0,
      desc = "Connect to devcontainer.",
    }
  )
end

return M
