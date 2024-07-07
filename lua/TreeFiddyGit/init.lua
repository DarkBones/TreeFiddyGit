local Job = require("plenary.job")
local worktree_parser = require("TreeFiddyGit.parsers.worktrees_parser")
local utils = require("TreeFiddyGit.utils")

local M = {}

-- TODO: Make a configurable worktrees folder. Can store them in root, or in root/worktrees
M.config = {
    change_directory_cmd = "cd",
    pre_create_worktree_hook = nil,
    post_create_worktree_hook = nil,
    pre_move_to_worktree_hook = nil,
    post_move_to_worktree_hook = nil,
    pre_delete_worktree_hook = nil,
    post_delete_worktree_hook = nil,
}

M.setup = function(opts)
    opts = opts or {}
    local options = M.config

    options = utils.merge_tables(options, opts)

    M.config = options
    require("telescope").load_extension("tree_fiddy_git")
end

-- TODO: Make a check if the current git repo is supported (bare repo, etc)

-- TODO: Flow for checking out remote branches and treeifying them
M.checkout_branch = function()
    -- Prompt the user for the branch name
    local branch_name = vim.fn.input("Enter the branch name: ")

    if branch_name == "" then
        return
    end

    utils.git_branch_exists(branch_name, function(exists, err)
        if err ~= nil then
            vim.schedule(function()
                vim.api.nvim_err_writeln(err)
            end)

            return
        end

        if exists ~= "none" then
            vim.schedule(function()
                local path = vim.fn.input("Enter path to worktree (defaults to branch name): ")
                if path == "" then
                    path = branch_name
                end

                utils.fetch_remote_branch(branch_name, function(_, err_fetch)
                    if err_fetch ~= nil then
                        vim.schedule(function()
                            vim.api.nvim_err_writeln(err_fetch)
                        end)
                        return
                    end

                    -- create a worktree for the existing branch
                    M.create_git_worktree(branch_name, path)
                end)
            end)
        else
            print("Branch `" .. branch_name .. "` not found.")
        end
    end)
end

M.get_git_worktrees = function(callback)
    Job:new({
        command = "git",
        args = { "worktree", "list" },
        on_exit = function(j, return_val)
            if return_val == 0 then
                local output = j:result()
                worktree_parser.parse_worktrees(output, function(parsed_output)
                    callback(parsed_output, nil)
                end)
            else
                callback(nil, "Error running git worktree list")
            end
        end,
    }):start()
end

--- This function creates a new git branch and a new git worktree.
-- It first creates a new git branch with the given branch name without checking it out.
-- Then, it creates a new git worktree with the given path.
-- Finally, it switches to the new worktree.
-- @param branch_name string: The name of the new git branch to be created.
-- @param path string: The path where the new git worktree will be created.
M.create_new_git_worktree = function(branch_name, path)
    utils.create_git_branch(branch_name, function(_, err)
        if err ~= nil then
            vim.schedule(function()
                vim.api.nvim_err_writeln(err)
            end)
            return
        end

        M.create_git_worktree(branch_name, path)
    end)
end

M.create_new_git_worktree_with_stash = function(branch_name, path)
    utils.stash(function(has_stashed, err)
        if err ~= nil then
            vim.schedule(function()
                vim.api.nvim_err_writeln(err)
            end)
            return
        end

        utils.create_git_branch(branch_name, function(_, err_create)
            if err_create ~= nil then
                vim.schedule(function()
                    vim.api.nvim_err_writeln(err_create)
                end)
                utils.stash_pop()
                return
            end

            M.create_git_worktree(branch_name, path, function(_, err_wt)
                if err_wt ~= nil then
                    if has_stashed then
                        utils.stash_pop()
                    end
                    return
                end

                if has_stashed then
                    utils.stash_pop(function(_, err_pop)
                        if err_pop ~= nil then
                            vim.schedule(function()
                                vim.api.nvim_err_writeln(err_pop)
                            end)
                            return
                        end

                        print("successfully moved changes to new worktree")
                    end)
                end
            end)
        end)
    end)
end

--- This function creates a new git worktree from an existing branch.
-- It first gets the absolute path of the worktree.
-- It creates a new git worktree at the absolute path with the branch name.
-- If the worktree is created successfully, it switches to the worktree.
-- @param branch_name string: The name of the existing git branch.
-- @param path string: The path where the new git worktree will be created.
M.create_git_worktree = function(branch_name, path, callback)
    utils.get_absolute_wt_path(path, function(wt_path, err)
        if err ~= nil then
            vim.schedule(function()
                vim.api.nvim_err_writeln(err)
            end)
            return
        end

        local data_pre_create = {
            branch_name = branch_name,
            path = path,
            abs_path = wt_path,
        }

        utils.run_hook(M.config.pre_create_worktree_hook, data_pre_create)

        Job:new({
            command = "git",
            args = { "worktree", "add", wt_path, branch_name },
            on_exit = function(_, return_val)
                local data_post_create = {
                    return_val = return_val,
                }
                data_post_create = utils.merge_tables(data_post_create, data_pre_create)
                utils.run_hook(M.config.post_create_worktree_hook, data_post_create)

                if return_val == 0 then
                    M.move_to_worktree(wt_path, function(_, err_wt)
                        if err_wt ~= nil then
                            if callback ~= nil then
                                callback(nil, err_wt)
                                return
                            end
                        end

                        if callback ~= nil then
                            callback(nil, nil)
                        end
                    end)
                else
                    local err_msg = "Error creating git worktree"
                    if callback then
                        callback(nil, err_msg)
                        return
                    end
                end
            end,
        }):start()
    end)
end

--- This function is called when a worktree is selected in the Telescope picker.
-- It changes the root directory in Neovim to the selected worktree and updates
-- the paths of all open buffers.
-- If a buffer's file does not exist in the new worktree, assume the user just
-- has a random file open and do nothing.
-- @param path The path of the selected worktree.
M.move_to_worktree = function(branch_name, path, callback)
    utils.current_branch(function(old_branch, err_curr_branch)
        if err_curr_branch ~= nil then
            vim.schedule(function()
                vim.api.nvim_err_writeln(err_curr_branch)
            end)
            return
        end

        utils.get_absolute_wt_path(path, function(wt_path)
            local data_pre_move = {
                old_branch = old_branch,
                new_branch = branch_name,
                path = path,
                absolute_path = wt_path,
            }
            utils.run_hook(M.config.pre_move_to_worktree_hook, data_pre_move)

            vim.schedule(function()
                vim.cmd(M.config.change_directory_cmd .. " " .. wt_path)
            end)

            utils.get_git_path(function(old_git_path)
                -- Change the paths of all open buffers
                vim.schedule(function()
                    local windows = vim.api.nvim_list_wins()

                    for _, win in ipairs(windows) do
                        local buf = vim.api.nvim_win_get_buf(win)
                        local buf_path = vim.api.nvim_buf_get_name(buf)
                        local new_buf_path = utils.update_worktree_buffer_path(old_git_path, wt_path, buf_path)

                        if new_buf_path then
                            vim.api.nvim_buf_set_name(buf, new_buf_path)
                            vim.api.nvim_set_current_win(win)
                            vim.api.nvim_command("edit")
                        end
                    end

                    local data_post_move = {
                        previous_path = old_git_path,
                    }
                    data_post_move = utils.merge_tables(data_post_move, data_pre_move)
                    utils.run_hook(M.config.post_move_to_worktree_hook, data_post_move)

                    if callback ~= nil then
                        callback(nil, nil)
                    end
                end)
            end)
        end)
    end)
end

M.delete_worktree = function(branch_name, path)
    utils.current_branch(function(current_branch, err_current_branch)
        if err_current_branch ~= nil then
            vim.schedule(function()
                vim.api.nvim_err_writeln(err_current_branch)
            end)
            return
        end

        utils.get_absolute_wt_path(path, function(wt_path)
            local data_pre_delete = {
                current_branch = current_branch,
                branch = branch_name,
                path = path,
                absolute_path = wt_path,
            }
            utils.run_hook(M.config.pre_delete_worktree_hook, data_pre_delete)

            utils.remove_worktree(path, function(_, err_remove)
                if err_remove ~= nil then
                    local force = vim.fn.input("Failed to remove. Try to force? [y/n]: ")
                    if string.lower(force) ~= "y" then
                        return
                    end

                    utils.force_delete_worktree(path, function(_, err_force)
                        if err_force ~= nil then
                            vim.schedule(function()
                                vim.api.nvim_err_writeln(err_force)
                            end)
                            return
                        end

                        utils.run_hook(M.config.post_delete_worktree_hook, data_pre_delete)
                    end)
                end

                utils.run_hook(M.config.post_delete_worktree_hook, data_pre_delete)
            end)
        end)
    end)
end

return M
