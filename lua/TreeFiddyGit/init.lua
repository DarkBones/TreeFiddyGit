local Job = require("plenary.job")
local worktree_parser = require("TreeFiddyGit.parsers.worktrees_parser")
local utils = require("TreeFiddyGit.utils")

local M = {}

-- TODO: Make a configurable worktrees folder. Can store them in root, or in root/worktrees
M.config = {
    change_directory_cmd = "cd",
}

-- TODO: Make a check if the current git repo is supported (bare repo, etc)

-- TODO: Flow for checking out remote branches and treeifying them
M.checkout_branch = function()
    -- Prompt the user for the branch name
    local branch_name = vim.fn.input("Enter the branch name: ")

    utils.git_branch_exists(branch_name, function(exists, err)
        if err ~= nil then
            vim.schedule(function()
                vim.api.nvim_err_writeln(err)
            end)

            return
        end

        if exists then
            vim.schedule(function()
                local path = vim.fn.input("Enter path to worktree (defaults to branch name): ")
                if path == "" then
                    path = branch_name
                end
                -- create a worktree for the existing branch
                -- WRONG FUNCTION. This ain't supposed to create a branch!
                --[[ utils.create_git_branch(branch_name, function(_, err_create)
                    if err_create ~= nil then
                        vim.api.nvim_err_writeln(err_create)
                        return
                    end
                end) ]]
                M.create_git_worktree(branch_name, path)
            end)
        else
            print("Branch `" .. branch_name .. "` not found.")
        end
    end)
end

M.setup = function(opts)
    opts = opts or {}
    local options = M.config

    for k, v in pairs(options) do
        if opts[k] == nil then
            opts[k] = v
        else
            options[k] = opts[k]
        end
    end

    M.config = options
    require("telescope").load_extension("tree_fiddy_git")
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
-- The function first creates a new git branch with the given branch name without checking it out.
-- Then, it creates a new git worktree with the given path.
-- @param branch_name string: The name of the new git branch to be created.
-- @param path string: The path where the new git worktree will be created.
M.create_new_git_worktree = function(branch_name, path)
    utils.create_git_branch(branch_name, function(_, err)
        if err ~= nil then
            vim.api.nvim_err_writeln(err)
            return
        end

        M.create_worktree(branch_name, path)
    end)
end

M.create_git_worktree = function(branch_name, path)
    print(branch_name)
    print(path)
end

M.create_git_worktree_old = function(branch_name, path, is_new_branch)
    -- git fetch origin branch_name:branch_name
    -- git worktree add path branch_name
    local fetch_args = { "fetch", "origin", branch_name .. ":" .. branch_name }
    -- local worktree_args = { "worktree", "add", path, branch_name }
    local worktree_args = { "worktree", "add" }
    if is_new_branch then
        table.insert(worktree_args, "-b")
    end
    table.insert(worktree_args, branch_name)
    table.insert(worktree_args, path)
    print(vim.inspect(worktree_args))

    utils.get_git_root_path(function(root_dir, err)
        if err ~= nil then
            vim.schedule(function()
                vim.api.nvim_err_writeln(err)
            end)
            return
        end

        if not string.match(path, "^worktrees/") then
            path = "worktrees/" .. path
        end

        path = root_dir .. "/" .. path

        Job:new({
            command = "git",
            args = fetch_args,
            on_exit = function(j, return_val)
                if return_val == 0 then
                    print("Branch fetched successfully")
                    Job:new({
                        command = "git",
                        args = worktree_args,
                        on_exit = function(_, return_val)
                            if return_val == 0 then
                                print("Worktree created successfully")
                                M.on_worktree_selected(path)
                            else
                                print("Error creating git worktree.")
                            end
                        end,
                    }):start()
                else
                    print("Error fetching branch. Git error message:")
                    print(table.concat(j:stderr_result(), "\n"))
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
M.on_worktree_selected = function(path)
    if not string.match(path, "^worktrees/") then
        path = "worktrees/" .. path
    end

    utils.get_git_root_path(function(git_root, err)
        if err ~= nil then
            vim.schedule(function()
                vim.api.nvim_err_writeln(err)
            end)
            return
        end

        local new_git_path = git_root .. "/" .. utils.make_relative(path, ".")
        vim.schedule(function()
            vim.cmd(M.config.change_directory_cmd .. " " .. new_git_path)
        end)

        utils.get_git_path(function(old_git_path)
            if not old_git_path then
                return
            end

            -- Change the root in vim
            vim.schedule(function()
                -- Change the paths of all open buffers
                for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
                    if vim.api.nvim_buf_is_valid(bufnr) then
                        local buf_path = vim.api.nvim_buf_get_name(bufnr)
                        local new_buf_path = utils.update_worktree_buffer_path(old_git_path, new_git_path, buf_path)

                        if new_buf_path then
                            vim.api.nvim_buf_set_name(bufnr, new_buf_path)
                            vim.api.nvim_command("edit!")
                        end
                    end
                end
            end)
        end)
    end)
end

return M
