local Job = require("plenary.job")
local logger = require("TreeFiddyGit.logger")

local M = {}

function M._run_job(command, args, callback)
    logger.log("INFO", "jobs.run_job")
    local err_message = ""

    Job:new({
        command = command,
        args = args,
        on_stderr = function(_, data)
            err_message = err_message .. "\n" .. data
        end,
        on_exit = function(j, return_val)
            if return_val ~= 0 then
                local full_err_msg = "Error running `"
                    .. command
                    .. " "
                    .. table.concat(args, " ")
                    .. "`"
                    .. err_message

                logger.log(logger.LogLevel.ERROR, "jobs._run_job", vim.inspect(err_message))

                callback(nil, full_err_msg)

                return
            end

            local error_arg = err_message ~= "" and err_message or nil
            callback(j:result(), error_arg)
        end,
    }):start()
end

--- This function returns a reference to the current git worktree.
-- The returned reference is in the format `path/to/gitrepo.git/worktrees/worktree_name`,
-- where `worktree_name` is the name of the current worktree.
-- The format is always gitrepo.git/worktrees/worktree_name, even if the worktree
-- is deeply nested in other worktrees.
-- @param callback function: The callback function to be called with the result.
function M._get_git_worktree_reference(callback)
    M._run_job("git", { "rev-parse", "--git-dir" }, function(res, err)
        logger.log(
            logger.LogLevel.DEBUG,
            "jobs._get_git_worktree_reference",
            "jobs._get_git_worktree_reference returned: " .. vim.inspect({ res, err })
        )

        if err ~= nil then
            logger.log(logger.LogLevel.ERROR, "jobs._get_git_worktree_reference", err)
            callback(nil, err)
            return
        end

        callback(res, nil)
    end)
end

function M._get_pwd(callback)
    -- M._run_job("pwd", nil, callback)
    M._run_job("pwd", nil, function(res, err)
        logger.log(logger.LogLevel.DEBUG, "jobs._get_pwd", "jobs._get_pwd returned: " .. vim.inspect({ res, err }))

        if err ~= nil then
            logger.log(logger.LogLevel.ERROR, "jobs._get_pwd", err)
            callback(nil, err)
            return
        end

        callback(res, nil)
    end)
end

--- Checks if the current directory is a bare Git repository.
-- A bare repository is a Git repository that doesn't have a working directory.
-- This function returns true if the current directory is a bare repository, and false otherwise.
-- /some/path/to/a_bare_repo.git >> true
-- /some/path/to/a_bare_repo.git/main >> false
function M._in_bare_repo(callback)
    M._run_job("git", { "rev-parse", "--is-bare-repository" }, function(res, err)
        logger.log(
            logger.LogLevel.DEBUG,
            "jobs._in_bare_repo",
            "jobs._in_bare_repo returned: " .. vim.inspect({ res, err })
        )

        if err ~= nil then
            logger.log(logger.LogLevel.ERROR, "jobs._in_bare_repo", err)
            callback(nil, err)
            return
        end

        callback(res, nil)
    end)
end

function M._branch_has_changes(callback)
    M._run_job("git", { "diff", "--quiet" }, function(_, err)
        if err then
            if err ~= "Error running `git diff --quiet`" then
                callback(nil, err)
                return
            end

            logger.log(logger.LogLevel.INFO, "jobs._branch_has_changes", "Branch has changes")
            callback(true, nil)
            return
        end

        logger.log(logger.LogLevel.INFO, "jobs._branch_has_changes", "Branch has no changes")
        callback(false, nil)
    end)
end

function M._git_branch_exists_locally(branch, callback)
    M._run_job("git", { "branch", "--list", "-a", branch }, function(res, err)
        if err ~= nil then
            logger.log(logger.LogLevel.ERROR, "jobs._git_branch_exists_locally", err)
            callback(nil, err)
            return
        end

        if next(res) == nil then
            logger.log(logger.LogLevel.INFO, "jobs._git_branch_exists_locally", "Branch does not exist")
            callback(false, nil)
            return
        end

        -- if res[1] starts with "*" then it is already checked out
        if res[1]:find("^%*") then
            callback(nil, "Branch is already checked out")
            return
        end

        logger.log(logger.LogLevel.INFO, "jobs._git_branch_exists_locally", "Branch exists")
        callback(true, nil)
    end)
end

function M._git_branch_exists_remotely(branch, callback)
    M._run_job(
        "bash",
        { "-c", "git ls-remote --heads " .. require("TreeFiddyGit").config.remote_name .. " " .. branch },
        function(res, err)
            if err then
                logger.log(logger.LogLevel.ERROR, "jobs._git_branch_exists_remotely", err)
                callback(nil, err)
                return
            end

            if next(res) == nil then
                logger.log(logger.LogLevel.INFO, "jobs._git_branch_exists_remotely", "Branch does not exist")
                callback(false, nil)
                return
            end

            logger.log(logger.LogLevel.INFO, "jobs._git_branch_exists_remotely", "Branch exists")
            callback(true, nil)
        end
    )
end

function M.get_worktrees(callback)
    M._run_job("git", { "worktree", "list" }, function(res, err)
        if err then
            logger.log(logger.LogLevel.ERROR, "jobs.get_worktrees", vim.inspect(err))
            callback(nil, err)
            return
        end

        callback(res, nil)
    end)
end

function M.git_path(callback)
    M._run_job("git", { "rev-parse", "--show-toplevel" }, function(res, err)
        if err ~= nil then
            logger.log(logger.LogLevel.ERROR, "jobs.git_path", err)
            callback(nil, nil)
            return
        end

        callback(res, nil)
    end)
end

function M.delete_worktree(worktree_path, callback)
    M._run_job("git", { "worktree", "remove", worktree_path }, function(_, err)
        if err ~= nil then
            if not err:find("--force") then
                logger.log(logger.Log.ERROR, "jobs.delete_worktree", err)
                callback(nil, err)
                return
            end

            logger.log(logger.LogLevel.WARN, "jobs.delete_worktree", err)

            vim.schedule(function()
                local force = vim.fn.input("Worktree is not clean. Do you want to force delete it? (y/n): ")
                if string.lower(force) ~= "y" then
                    logger.log(logger.LogLevel.INFO, "jobs.delete_worktree", "User chose not to force delete worktree")
                    callback(false, nil)
                    return
                end

                M._run_job("git", { "worktree", "remove", "--force", worktree_path }, function(_, force_err)
                    if force_err ~= nil then
                        logger.log(logger.LogLevel.ERROR, "jobs.delete_worktree", force_err)
                        callback(nil, force_err)
                        return
                    end

                    logger.log(logger.LogLevel.INFO, "jobs.delete_worktree", "Worktree deleted successfully")
                    callback(true, nil)
                end)
            end)
        end

        logger.log(logger.LogLevel.INFO, "jobs.delete_worktree", "Worktree deleted successfully")
        callback(true, nil)
    end)
end

--- This function returns the root path of the current git repository.
-- No matter where the command is run from, it will always get the root path of the git repository.
-- If a tree is nested in another tree, it won't affect the result.
-- If a user is in some deeply nested directory, it will still only return the root path
-- If the current directory is not a supported (bare) git repository, it throws an error.
function M.get_git_root_path(callback)
    logger.log(logger.LogLevel.DEBUG, "jobs.get_git_root_path", "getting git root path")

    M._get_git_worktree_reference(function(git_ref, git_ref_err)
        if git_ref_err ~= nil then
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
                    local err_message = "Not in a supported git repository"
                    logger.log(logger.LogLevel.ERROR, "jobs.get_git_root_path", err_message)
                    callback(nil, err_message)
                    return
                end

                M._get_pwd(function(pwd, pwd_err)
                    if pwd_err ~= nil then
                        callback(nil, pwd_err)
                        return
                    end

                    logger.log(logger.LogLevel.INFO, "jobs.get_git_root_path", "found root path: " .. vim.inspect(pwd))
                    callback(pwd[1], nil)
                end)
            end)
        elseif git_ref[1]:find(".+%.git/worktrees/") or git_ref[1]:find(".+%.git/worktrees$") then
            local root_path = git_ref[1]:match("^(.-%.git)/worktrees")
            logger.log(logger.LogLevel.INFO, "jobs.get_git_root_path", "found root path: " .. vim.inspect(root_path))
            callback(root_path, nil)
        elseif git_ref[1] == ".git" then
            local err_message = "Must be in a bare repo"
            logger.log(logger.LogLevel.ERROR, "jobs.get_git_root_path", err_message)
            callback(nil, err_message)
        else
            local err_message = "Failed to get git root path"
            logger.log(logger.LogLevel.ERROR, "jobs.get_git_root_path", err_message)
            callback(nil, err_message)
        end
    end)
end

function M.current_branch_and_path(callback)
    M._run_job("git", { "branch", "--show-current" }, function(cur_branch, err_curr_branch)
        if err_curr_branch ~= nil then
            logger.log(logger.LogLevel.ERROR, "jobs.current_branch_and_path", err_curr_branch)
            callback(nil, err_curr_branch)
            return
        end

        M._get_pwd(function(pwd, err_pwd)
            if err_pwd ~= nil then
                callback(nil, err_pwd)
                return
            end

            callback({ cur_branch[1], pwd[1] })
        end)
    end)
end

function M.create_git_branch(branch_name, callback)
    M._run_job("git", { "branch", branch_name }, function(_, err)
        if err ~= nil and not err:find("already exists") then
            logger.log(logger.LogLevel.ERROR, "jobs.create_git_branch", err)
            callback(nil, err)
            return
        end

        callback(true, nil)
    end)
end

function M.create_worktree(branch_and_path, callback)
    local branch_name = branch_and_path.branch_name
    local path = branch_and_path.path

    M._run_job("git", { "worktree", "add", path, branch_name }, function(_, err)
        if err and not string.find(err, "Preparing worktree") then
            logger.log(logger.LogLevel.ERROR, "jobs.create_worktree", err)
            callback(nil, err)
            return
        end

        callback(true, nil)
    end)
end

function M.stash(callback)
    M._branch_has_changes(function(has_changes, err_has_changes)
        if err_has_changes then
            callback(nil, err_has_changes)
            return
        end

        if not has_changes then
            callback(false, nil)
            return
        end

        M._run_job("git", { "stash" }, function(_, err_stash)
            if err_stash then
                logger.log(logger.LogLevel.ERROR, "jobs.stash", err_stash)
                callback(nil, err_stash)
                return
            end

            callback(true, nil)
        end)
    end)
end

function M.pop_stash(callback)
    M._run_job("git", { "stash", "pop" }, function(_, err)
        if err then
            logger.log(logger.LogLevel.ERROR, "jobs.pop_stash", err)
            callback(nil, err)
            return
        end

        callback(true, nil)
    end)
end

function M.git_branch_exists(branch, callback)
    M._git_branch_exists_locally(branch, function(exists_local, err)
        if err then
            if err == "Branch is already checked out" then
                vim.schedule(function()
                    vim.notify("Branch is already checked out", vim.log.levels.INFO)
                end)
                return
            end

            logger.log(logger.LogLevel.ERROR, "jobs.git_branch_exists", err)
            callback(nil, err)
        end

        if exists_local then
            local msg = "Branch exists locally"
            logger.log(logger.LogLevel.INFO, "jobs.git_branch_exists", msg)

            callback("local", nil)
            return
        end

        local msg = "Branch does not exist locally, checking remote..."
        logger.log(logger.LogLevel.INFO, "jobs.git_branch_exists", msg)
        vim.schedule(function()
            vim.notify(msg, vim.log.levels.INFO)
        end)

        M._git_branch_exists_remotely(branch, function(exists_remote, err_remote)
            if err_remote then
                logger.log(logger.LogLevel.ERROR, "jobs.git_branch_exists", err_remote)
                callback(nil, err_remote)
                return
            end

            if not exists_remote then
                local no_branch_msg = "Branch does not exist"
                logger.log(logger.LogLevel.WARN, "jobs.git_branch_exists", no_branch_msg)
                vim.notify(no_branch_msg, vim.log.levels.WARN)
                callback("none", nil)
                return
            end

            logger.log(logger.LogLevel.INFO, "jobs.git_branch_exists", "Branch exists remotely")
            callback("remote", nil)
        end)
    end)
end

function M.fetch_remote_branch(branch_name, callback)
    M._run_job(
        "git",
        { "fetch", require("TreeFiddyGit").config.remote_name, branch_name .. ":" .. branch_name },
        function(_, err)
            if err then
                logger.log(logger.LogLevel.ERROR, "jobs.fetch_remote_branch", err)
                callback(nil, err)
                return
            end

            callback(true, nil)
        end
    )
end

return M
