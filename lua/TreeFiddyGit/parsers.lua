local jobs = require("TreeFiddyGit.jobs")

local M = {}

function M.parse_worktrees(worktrees)
    -- TODO:
    jobs.get_git_root_path(function(root_path, root_path_err)
        print("root_path: " .. vim.inspect(root_path))
        print("root_path_err: " .. vim.inspect(root_path_err))
    end)
end

return M
