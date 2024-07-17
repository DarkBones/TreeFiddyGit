local jobs = require("TreeFiddyGit.jobs")

local M = {}

function M.setup(opts) end

function M.get_worktrees(callback)
    jobs.get_worktrees(function(worktrees, err_worktrees)
        if err_worktrees ~= nil then
            vim.schedule(function()
                vim.api.nvim_err_writeln(err_worktrees)
            end)

            return
        end

        callback(worktrees, nil)
    end)
end

return M
