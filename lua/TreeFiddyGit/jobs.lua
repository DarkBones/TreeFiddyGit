local Job = require("plenary.job")

local M = {}

function M._run_job(command, args, callback)
    local err_message = ""

    Job
        :new({
            command = command,
            args = args,
            on_stderr = function(_, data)
                err_message = err_message .. "\n" .. data
            end,
            on_exit = function(j, return_val)
                if return_val ~= 0 then
                    local full_err_msg = "Error running`"
                        .. command
                        .. " "
                        .. table.concat(args, " ")
                        .. "`"
                        .. err_message
                    callback(nil, full_err_msg)

                    return
                end

                local error_arg = err_message ~= "" and err_message or nil
                callback(j:result(), error_arg)
            end,
        })
        :start()
end

--- This function returns a reference to the current git worktree.
-- The returned reference is in the format `path/to/gitrepo.git/worktrees/worktree_name`,
-- where `worktree_name` is the name of the current worktree.
-- The format is always gitrepo.git/worktrees/worktree_name, even if the worktree
-- is deeply nested in other worktrees.
-- @param callback function: The callback function to be called with the result.
function M._get_git_worktree_reference(callback)
    M._run_job("git", { "rev-parse", "--git-dir" }, callback)
end

function M._git_pwd(callback)
    M._run_job("pwd", nil, callback)
end

--- Checks if the current directory is a bare Git repository.
-- A bare repository is a Git repository that doesn't have a working directory.
-- This function returns true if the current directory is a bare repository, and false otherwise.
-- /some/path/to/a_bare_repo.git >> true
-- /some/path/to/a_bare_repo.git/main >> false
function M._in_bare_repo(callback)
    M._run_job("git", { "rev-parse", "--is-bare-repository" }, callback)
end

function M.get_worktrees(callback)
    M._run_job("git", { "worktree", "list" }, callback)
end

--- This function returns the root path of the current git repository.
-- No matter where the command is run from, it will always get the root path of the git repository.
-- If a tree is nested in another tree, it won't affect the result.
-- If a user is in some deeply nested directory, it will still only return the root path
-- If the current directory is not a supported (bare) git repository, it throws an error.
function M.get_git_root_path(callback)
    M._get_git_worktree_reference(function(git_ref, git_ref_err)
        if git_ref == nil then
            callback(nil, git_ref_err)
            return
        end

        if git_ref[1] == "." then
            M._in_bare_repo(function(is_bare, is_bare_err)
                if is_bare_err ~= nil then
                    callback(nil, is_bare_err)
                    return
                end

                if is_bare[1] ~= "true" then
                    callback(nil, "Not in a supported git repository")
                    return
                end

                M._git_pwd(function(pwd, pwd_err)
                    if pwd_err ~= nil then
                        callback(nil, pwd_err)
                        return
                    end

                    callback(pwd, nil)
                end)
            end)
        elseif git_ref[1]:find(".+%.git/worktrees/") or git_ref[1]:find(".+%.git/worktrees$") then
            local root_path = git_ref[1]:match("^(.-%.git)/worktrees")
            callback(root_path, nil)
        elseif git_ref[1] == ".git" then
            callback(nil, "Must be in a bare repo")
        else
            callback(nil, "Failed to get git root path")
        end
    end)
end

return M
