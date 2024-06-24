local Job = require("plenary.job")
local path_utils = require("plenary.path")

local M = {}

M.make_relative = function(path, base)
    return path_utils.new(path):make_relative(base)
end

--- This function returns a reference to the current git worktree.
-- The returned reference is in the format `path/to/gitrepo.git/worktrees/worktree_name`,
-- where `worktree_name` is the name of the current worktree.
-- The format is always gitrepo.git/worktrees/worktree_name, even if the worktree
-- is deeply nested in other worktrees.
-- @param callback function: The callback function to be called with the result.
M._get_git_worktree_reference = function(callback)
    Job:new({
        command = "git",
        args = { "rev-parse", "--git-dir" },
        on_exit = function(j, return_val)
            if return_val == 0 then
                local result = j:result()[1]
                callback(result:match("^%s*(.-)%s*$"))
            else
                error("Failed to run `git rev-parse --git-dir`")
            end
        end,
    }):start()
end

--- This function returns the current working directory.
-- @param callback function: The callback function to be called with the result.
M._get_pwd = function(callback)
    Job:new({
        command = "pwd",
        on_exit = function(j, return_val)
            if return_val == 0 then
                local result = j:result()[1]
                callback(result:match("^%s*(.-)%s*$"))
            else
                error("Failed to run pwd")
            end
        end,
    }):start()
end

--- This function returns the actual path of the current git worktree.
-- The returned path is the root path of the current worktree, regardless of
-- how deeply nested the current directory is within the worktree.
-- @param callback function: The callback function to be called with the result.
M.get_git_path = function(callback)
    -- TODO: Plenary job
    Job:new({
        command = "git",
        args = { "rev-parse", "--show-toplevel" },
        on_exit = function(j, return_val)
            if return_val == 0 then
                local result = j:result()[1]
                callback(result:match("^%s*(.-)%s*$"))
            else
                error("Failed to run `git rev-parse --show-toplevel`")
            end
        end
    }):start()
end

--- This function returns the root path of the current git repository.
-- No matter where the command is run from, it will always get the root path of the git repository.
-- If a tree is nested in another tree, it won't affect the result.
-- If a user is in some deeply nested directory, it will still only return the root path
-- If the current directory is not a supported (bare) git repository, it throws an error.
-- @param callback function: The callback function to be called with the result.
M.get_git_root_path = function(callback)
    M._get_git_worktree_reference(function(root_path)
        if root_path == nil then
            error("Not in a git repository")
        end

        if root_path == "." then
            -- local pwd = M._get_pwd()
            M._get_pwd(function(pwd)
                if pwd:sub(-4) == ".git" then
                    callback(pwd)
                else
                    error("Not in a git repository")
                end
            end)
        elseif root_path == ".git" then
            error("Not in a supported git repository. Must be bare")
        elseif root_path:find(".git/worktrees/") then
            -- remove the current branch from the path
            root_path = root_path:match("^(.+.git)/worktrees.*")
            callback(root_path)
        else
            error("Failed to get git root path")
        end
    end)
end

M.update_worktree_buffer_path = function(old_git_path, new_git_path, buf_path)
    if buf_path:sub(1, #old_git_path) ~= old_git_path then
        return nil
    end

    local buf_relative_path = buf_path:sub(#old_git_path + 1)

    return new_git_path .. buf_relative_path
end

return M
