local jobs = require("TreeFiddyGit.jobs")
local parsers = require("TreeFiddyGit.parsers")
local utils = require("TreeFiddyGit.utils")
local logger = require("TreeFiddyGit.logger")

local M = {}

M.default_config = {
    change_directory_cmd = "cd",
    hook = nil,
    branch_parser = nil,
    path_parser = nil,
    auto_move_to_new_worktree = true,
    remote_name = "origin",
    logging = {
        level = nil,
        file = vim.fn.stdpath("config") .. "/TreeFiddyGit.log",
        max_size = 1024 * 1024 * 5, -- 5mb
        rolling_file = false,
    },
}

M.config = {}

function M.setup(opts)
    opts = opts or {}
    M.config = utils.deep_merge(vim.deepcopy(M.default_config), opts)
    logger.log(logger.LogLevel.DEBUG, "TreeFiddyGit.setup", "Loaded with config: " .. vim.inspect(M.config))
end

function M.get_worktrees(callback)
    jobs.get_worktrees(function(worktrees, err_worktrees)
        if err_worktrees then
            logger.log(
                logger.LogLevel.ERROR,
                "TreeFiddyGit.get_worktrees",
                "Failed with: " .. vim.inspect(err_worktrees)
            )
            vim.schedule(function()
                vim.api.nvim_err_writeln(err_worktrees)
            end)
            return
        end

        parsers.parse_worktrees(worktrees, function(parsed_worktrees)
            callback(parsed_worktrees)
        end)
    end)
end

function M._handle_errors(err)
    vim.schedule(function()
        vim.api.nvim_err_writeln(err)
    end)
end

function M._update_buffers(git_path, abs_path)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        local buf_path = vim.api.nvim_buf_get_name(buf)
        local new_buf_path = utils.update_worktree_buffer_path(git_path[1], abs_path, buf_path)

        logger.log(
            logger.LogLevel.DEBUG,
            "TreeFiddyGit.move_to_worktree",
            { buf_path = buf_path, new_buf_path = new_buf_path }
        )

        if new_buf_path ~= buf_path then
            vim.api.nvim_buf_set_name(buf, new_buf_path)
            vim.api.nvim_set_current_win(win)
            vim.api.nvim_command("edit")
        end
    end
end

function M._perform_move(abs_path, hook_data, callback)
    logger.log(
        logger.LogLevel.DEBUG,
        "TreeFiddyGit._perform_move",
        "called with: " .. vim.inspect({ abs_path, hook_data })
    )

    vim.schedule(function()
        vim.cmd(M.config.change_directory_cmd .. " " .. abs_path)
    end)

    jobs.git_path(function(git_path)
        if git_path then
            vim.schedule(function()
                M._update_buffers(git_path, abs_path)
                logger.log(logger.LogLevel.INFO, "TreeFiddyGit.move_to_worktree", "Moved to worktree: " .. abs_path)
            end)
        end

        utils.run_hook("post_move_to_worktree", hook_data)
        if callback then
            callback(true, nil)
        end
    end)
end

function M._current_is_valid(current_branch, current_path)
    if not current_path or not current_branch then
        local err_msg = current_path and "Failed to get current branch" or "Failed to get current path"
        logger.log(logger.LogLevel.ERROR, "TreeFiddyGit.move_to_worktree", err_msg)
        M._handle_errors(err_msg)
        return false
    end

    return true
end

function M.move_to_worktree(branch_name, path, callback)
    logger.log(
        logger.LogLevel.DEBUG,
        "TreeFiddyGit.move_to_worktree",
        "Called with: " .. vim.inspect({ branch_name, path })
    )

    jobs.current_branch_and_path(function(current, err_current)
        if err_current then
            M._handle_errors(err_current)
            if callback then
                callback(nil, err_current)
            end
            return
        end

        local current_branch, current_path = current[1], current[2]
        if not M._current_is_valid(current_branch, current_path) then
            if callback then
                callback(nil, err_current)
            end
            return
        end

        utils.get_absolute_wt_path(path, function(abs_path, err_abs_path)
            if err_abs_path then
                M._handle_errors(err_abs_path)
                if callback then
                    callback(nil, err_current)
                end
                return
            end

            local hook_data = {
                branch_name = branch_name,
                path = path,
                current_branch = current_branch,
                current_path = current_path,
                abs_worktree_path = abs_path,
            }
            utils.run_hook("pre_move_to_worktree", hook_data)

            M._perform_move(abs_path, hook_data, function()
                if callback then
                    callback(nil, err_current)
                end
            end)
        end)
    end)
end

function M.delete_worktree(branch_name, path)
    logger.log(
        logger.LogLevel.DEBUG,
        "TreeFiddyGit.delete_worktree",
        "Called with: " .. vim.inspect({ branch_name, path })
    )

    jobs.current_branch_and_path(function(current, err_current)
        if err_current then
            M._handle_errors(err_current)
            return
        end

        local current_branch, current_path = current[1], current[2]
        if not M._current_is_valid(current_branch, current_path) then
            return
        end

        utils.get_absolute_wt_path(path, function(abs_path, err_abs_path)
            if err_abs_path then
                M._handle_errors(err_abs_path)
                return
            end

            local hook_data = {
                branch_name = branch_name,
                path = path,
                current_branch = current_branch,
                current_path = current_path,
                abs_worktree_path = abs_path,
            }
            utils.run_hook("pre_delete_worktree", hook_data)

            jobs.delete_worktree(path, function(delete_result, delete_err)
                if delete_err then
                    M._handle_errors(delete_err)
                    return
                end

                if delete_result then
                    logger.log(logger.LogLevel.INFO, "TreeFiddyGit.delete_worktree", "Deleted worktree: " .. path)
                    vim.schedule(function()
                        vim.notify("Deleted worktree: " .. path, vim.log.levels.INFO)
                    end)
                    utils.run_hook("post_delete_worktree", hook_data)
                else
                    logger.log(
                        logger.LogLevel.INFO,
                        "TreeFiddyGit.delete_worktree",
                        "Did not delete worktree: " .. path
                    )
                    vim.schedule(function()
                        vim.notify("Did not delete worktree: " .. path, vim.log.levels.INFO)
                    end)
                end
            end)
        end)
    end)
end

function M.create_worktree(branch_name, path, callback)
    logger.log(
        logger.LogLevel.DEBUG,
        "TreeFiddyGit.create_worktree",
        "Called with: " .. vim.inspect({ branch_name, path })
    )

    utils.get_absolute_wt_path(path, function(wt_path, wt_path_err)
        if wt_path_err then
            M._handle_errors(wt_path_err)
            if callback then
                callback(nil, wt_path_err)
            end
            return
        end

        jobs.current_branch_and_path(function(current, err_current)
            if err_current then
                M._handle_errors(err_current)
                if callback then
                    callback(nil, err_current)
                end
                return
            end

            local current_branch, current_path = current[1], current[2]
            if not M._current_is_valid(current_branch, current_path) then
                if callback then
                    callback(nil, "invalid current branch or path")
                end
                return
            end

            local hook_data = {
                branch_name = branch_name,
                path = path,
                current_branch = current_branch,
                current_path = current_path,
                abs_worktree_path = wt_path,
            }
            utils.run_hook("pre_create_worktree", hook_data)

            local branch_and_path = {
                branch_name = branch_name,
                path = wt_path,
            }
            jobs.create_worktree(branch_and_path, function(_, create_err)
                if create_err then
                    M._handle_errors(create_err)
                    if callback then
                        callback(nil, create_err)
                    end
                    return
                end

                logger.log(logger.LogLevel.INFO, "TreeFiddyGit.create_worktree", "Created worktree: " .. wt_path)
                vim.schedule(function()
                    vim.notify("Created worktree: " .. wt_path, vim.log.levels.INFO)
                end)
                utils.run_hook("post_create_worktree", hook_data)
                callback(true, nil)
            end)
        end)
    end)
end

function M.create_new_worktree(branch_name, path, callback)
    jobs.create_git_branch(branch_name, function(_, create_err)
        if create_err then
            M._handle_errors(create_err)
            if callback then
                callback(nil, create_err)
            end
            return
        end

        M.create_worktree(branch_name, path, function(_, create_wt_err)
            if create_wt_err then
                M._handle_errors(create_wt_err)
                if callback then
                    callback(nil, create_err)
                end
                return
            end

            if M.config.auto_move_to_new_worktree or callback then
                M.move_to_worktree(branch_name, path, function(_, err_move)
                    if err_move then
                        M._handle_errors(err_move)
                        if callback then
                            callback(nil, err_move)
                        end
                        return
                    end

                    if callback then
                        callback(true, nil)
                    end
                end)
            else
                if callback then
                    callback(true, nil)
                end
            end
        end)
    end)
end

function M.create_new_worktree_with_stash(branch_name, path)
    jobs.stash(function(has_stashed, stashed_err)
        if stashed_err then
            M._handle_errors(stashed_err)
            return
        end

        M.create_new_worktree(branch_name, path, function(_, err_create)
            if err_create then
                M._handle_errors(err_create)
                return
            end

            if has_stashed then
                jobs.pop_stash(function(_, pop_err)
                    if pop_err then
                        M._handle_errors(pop_err)
                        return
                    end

                    vim.schedule(function()
                        vim.notify("Moved changes to new worktree")
                    end)
                end)
            end
        end)
    end)
end

function M._post_checkout_create_worktree(branch_name, path)
    M.create_worktree(branch_name, path, function(_, err_create)
        if err_create then
            M._handle_errors(err_create)
            return
        end

        M.move_to_worktree(branch_name, path, function(_, err_move)
            if err_move then
                M._handle_errors(err_move)
                return
            end
        end)
    end)
end

function M.checkout_branch()
    local branch_name = vim.fn.input("Enter the branch name: ")

    if branch_name == "" then
        return
    end

    jobs.current_branch_and_path(function(current, err_current)
        if err_current then
            M._handle_errors(err_current)
            return
        end

        local current_branch, current_path = current[1], current[2]
        if not M._current_is_valid(current_branch, current_path) then
            return
        end

        local hook_data = {
            branch_name = branch_name,
            current_branch = current_branch,
            current_path = current_path,
        }
        utils.run_hook("pre_checkout_branch", hook_data)

        jobs.git_branch_exists(branch_name, function(res_exists, err_exists)
            if err_exists then
                M._handle_errors(err_exists)
                return
            end

            if res_exists == "none" then
                M._handle_errors("Branch does not exist: " .. branch_name)
                return
            end

            vim.schedule(function()
                local path = vim.fn.input("Enter path to worktree (defaults to branch name): ")
                if path == "" then
                    path = branch_name
                end

                hook_data = utils.deep_merge(hook_data, { path = path, branch_location = res_exists })

                if res_exists == "remote" then
                    jobs.fetch_remote_branch(branch_name, function(_, fetch_err)
                        if fetch_err then
                            if not string.find(fetch_err, "%[new branch%]") then
                                M._handle_errors(fetch_err)
                                return
                            end
                        end

                        M._post_checkout_create_worktree(branch_name, path)
                    end)
                else
                    M._post_checkout_create_worktree(branch_name, path)
                end
            end)
        end)
    end)
end

return M
