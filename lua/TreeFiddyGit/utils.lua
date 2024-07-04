local Job = require("plenary.job")
local path_utils = require("plenary.path")

local M = {}

M.BranchLocation = {
    NONE = "none",
    LOCAL = "local",
    REMOTE = "remote",
}

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
                callback(result:match("^%s*(.-)%s*$"), nil)
            else
                callback(nil, "Failed to run `git rev-parse --git-dir`")
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
                callback(result:match("^%s*(.-)%s*$"), nil)
            else
                callback(nil, "Failed to run pwd")
            end
        end,
    }):start()
end

M._git_branch_exists_locally = function(branch, callback)
    Job:new({
        command = "git",
        args = { "branch", "--list", "-a", branch },
        on_exit = function(j, return_val)
            if return_val == 0 then
                if j:result()[1] == nil then
                    callback(false, nil)
                else
                    callback(true, nil)
                end
            else
                callback(nil, "Failed to run git branch --list -a " .. branch)
            end
        end,
    }):start()
end

M._git_branch_exists_remote = function(branch, callback)
    Job:new({
        command = "bash",
        args = { "-c", "git ls-remote --heads origin " .. branch },
        on_exit = function(j, return_val)
            if return_val == 0 then
                if j:result()[1] ~= nil then
                    -- The branch exists on remote
                    callback(true, nil)
                else
                    -- The branch does not exist on remote
                    callback(false, nil)
                end
            else
                callback(nil, "Failed to call `git ls-remote --heads origin " .. branch)
            end
        end,
    }):start()
end

M._branch_has_changes = function(callback)
    Job:new({
        command = "git",
        args = { "diff", "--quiet" },
        on_exit = function(_, return_val)
            if return_val == 0 then
                callback(false)
            else
                callback(true)
            end
        end,
    }):start()
end

M.stash = function(callback)
    M._branch_has_changes(function(has_changes)
        if not has_changes then
            callback(false, nil)
            return
        end

        Job:new({
            command = "git",
            args = { "stash" },
            on_exit = function(_, return_val)
                if return_val == 0 then
                    callback(true, nil)
                else
                    callback(nil, "Failed to run `git stash`")
                end
            end,
        }):start()
    end)
end

M.stash_pop = function(callback)
    Job:new({
        command = "git",
        args = { "stash", "pop" },
        on_exit = function(_, return_val)
            if return_val == 0 then
                if callback ~= nil then
                    callback(nil, nil)
                end
            else
                if callback ~= nil then
                    callback(nil, "Failed to pop stash")
                end
            end
        end,
    }):start()
end

M.create_git_branch = function(branch_name, callback)
    Job:new({
        command = "git",
        args = { "branch", branch_name },
        on_exit = function(_, return_val)
            if return_val == 0 then
                callback(nil, nil)
            else
                callback(nil, "Failed to call `git branch " .. branch_name .. "`")
            end
        end,
    }):start()
end

M.git_branch_exists = function(branch, callback)
    M._git_branch_exists_locally(branch, function(exists_locally, err_local)
        if err_local ~= nil then
            callback(nil, err_local)
            return
        end

        if exists_locally then
            callback(M.BranchLocation.LOCAL, nil)
        else
            print(branch .. " not found locally. Checking remote...")
            M._git_branch_exists_remote(branch, function(exists_remote, err_remote)
                if err_remote ~= nil then
                    callback(nil, err_remote)
                    return
                end

                if exists_remote then
                    callback(M.BranchLocation.REMOTE, nil)
                else
                    callback(M.BranchLocation.NONE, nil)
                end
            end)
        end
    end)
end

M.current_branch = function(callback)
    Job:new({
        command = "git",
        args = { "branch", "--show-current" },
        on_exit = function(j, return_val)
            if return_val == 0 then
                local result = j:result()[1]
                callback(result:match("^%s*(.-)%s*$"), nil)
            else
                callback(nil, "Failed to run `git branch --show-current`")
            end
        end
    }):start()
end

--- This function returns the actual path of the current git worktree.
-- The returned path is the root path of the current worktree, regardless of
-- how deeply nested the current directory is within the worktree.
-- @param callback function: The callback function to be called with the result.
M.get_git_path = function(callback)
    Job:new({
        command = "git",
        args = { "rev-parse", "--show-toplevel" },
        on_exit = function(j, return_val)
            if return_val == 0 then
                local result = j:result()[1]
                callback(result:match("^%s*(.-)%s*$"), nil)
            else
                callback(nil, nil)
            end
        end,
    }):start()
end

M.delete_worktree = function(path, callback)
    Job:new({
        command = "git",
        args = { "worktree", "remove", path },
        on_exit = function(j, return_val)
            if return_val == 0 then
                callback(nil, nil)
            else
                callback(nil, "Failed to run git worktree remove")
            end
        end
    }):start()
end

M.force_delete_worktree = function(path, callback)
    Job:new({
        command = "git",
        args = { "worktree", "remove", path, "--force" },
        on_exit = function(j, return_val)
            if return_val == 0 then
                callback(nil, nil)
            else
                callback(nil, "Failed to run git worktree remove --force")
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
            callback(nil, "Not in a git repository")
            return
        end

        if root_path == "." then
            M._get_pwd(function(pwd, pwd_err)
                if pwd == nil then
                    callback(nil, pwd_err)
                end

                if pwd:sub(-4) == ".git" then
                    callback(pwd, nil)
                else
                    callback(nil, "Not in a git repository")
                end
            end)
        elseif root_path == ".git" then
            callback(nil, "Not in a supported git repository. Must be bare")
        elseif root_path:find(".git/worktrees/") then
            -- remove the current branch from the path
            root_path = root_path:match("^(.+.git)/worktrees.*")
            callback(root_path, nil)
        else
            callback(nil, "Failed to get git root path")
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

M.fetch_remote_branch = function(branch_name, callback)
    Job:new({
        command = "git",
        args = { "fetch", "origin", branch_name .. ":" .. branch_name },
        on_exit = function(_, return_val)
            if return_val == 0 then
                callback(nil, nil)
            else
                callback(nil, "Failed to run `git fetch origin " .. branch_name .. ":" .. branch_name .. "`")
            end
        end,
    }):start()
end

M.get_absolute_wt_path = function(path, callback)
    if string.sub(path, 1, 2) == "./" then
        path = string.sub(path, 3)
    end

    M.get_git_root_path(function(root_path, err)
        if err ~= nil then
            vim.schedule(function()
                vim.api.nvim_err_writeln(err)
            end)
            callback(nil, err)
        end

        if string.sub(path, 1, #root_path) ~= root_path then
            path = root_path .. "/" .. path
        end

        callback(path, nil)
    end)
end

M.run_hook = function(hook, data)
    if hook ~= nil then
        if type(hook) == "string" then
            os.execute(hook)
        elseif type(hook) == "function" then
            hook(data)
        end
    end
end

M.merge_tables = function (t1, t2)
    for k, v in pairs(t2) do
        t1[k] = v
    end
    return t1
end

return M
