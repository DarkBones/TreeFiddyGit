local Job = require("plenary.job")

local M = {}

--- This function returns a reference to the current git worktree.
-- The returned reference is in the format `path/to/gitrepo.git/worktrees/worktree_name`,
-- where `worktree_name` is the name of the current worktree.
-- The format is always gitrepo.git/worktrees/worktree_name, even if the worktree
-- is deeply nested in other worktrees.
-- @param callback function: The callback function to be called with the result.
function M._get_git_worktree_reference(callback)
    Job:new({
        command = "git",
        args = { "rev-parse", "--git-dir" },
        on_exit = function(j, return_val)
            if return_val ~= 0 then
                callback(nil, "Error running git rev-parse --git-dir")
            end

            -- if return_val == 0 then
            --     local result = j:result()[1]
            --     callback(result:match("^%s*(.-)%s*$"), nil)
            -- else
            --     callback(nil, "Failed to run `git rev-parse --git-dir`")
            -- end
        end,
    }):start()
end

function M.get_worktrees(callback)
    local err_message = ""

    Job:new({
        command = "git",
        args = { "worktree", "list" },
        on_stderr = function(_, data)
            err_message = err_message .. "\n" .. data
        end,
        on_exit = function(j, return_val)
            if return_val ~= 0 then
                callback(nil, "Error running `git worktree list`" .. err_message)

                return
            end

            callback(j:result(), nil)
        end,
    }):start()
end

function M.get_git_root_path(callback) end

return M
