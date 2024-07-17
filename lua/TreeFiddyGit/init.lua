local jobs = require("TreeFiddyGit.jobs")
local parsers = require("TreeFiddyGit.parsers")

local M = {}

function M.setup(opts) end

function M.get_worktrees(callback)
    jobs.get_worktrees(function(worktrees, err_worktrees)
        if err_worktrees ~= nil then
            print("Error running `git worktree list`: " .. #err_worktrees .. " --end")
            vim.schedule(function()
                vim.api.nvim_err_writeln(err_worktrees)
            end)

            return
        end

        parsers.parse_worktrees(worktrees)
        callback(worktrees, nil)
    end)
end

return M
