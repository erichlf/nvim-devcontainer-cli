local folder_utils = require("devcontainer_cli.folder_utils")

describe("In folder_utils functions", function()
  it(
    "checks if get_root function has the root folder as a reference even when we are in another folder",
    function()
      -- dbg()
      -- This test assumes that we are in the root folder of the project
      local project_root_folder = vim.fn.getcwd()
      -- We change the current directory to a subfolder
      vim.fn.chdir("lua/devcontainer_cli")
      local devcontainer_cli_folder = vim.fn.getcwd()
      -- First we check that the we properly changed the directory
      assert(devcontainer_cli_folder == project_root_folder .. "/lua/devcontainer_cli")
      -- In such subfolder the function for getting the root_folder is called
      local root_folder = folder_utils.get_root()
      -- From the subfolder, we check that the get_root function returns the folder where the git repo is located instead of the CWD
      print("ROOT" .. root_folder)
      print("PROJECT_ROOT" .. project_root_folder)
      assert(root_folder == project_root_folder)
      -- After running the test we come back to the initial location
      vim.fn.chdir(project_root_folder)
    end
  )
end)
