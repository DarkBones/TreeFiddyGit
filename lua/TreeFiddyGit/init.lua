local Job = require("plenary.job")
local worktree_parser = require("TreeFiddyGit.parsers.worktrees_parser")
local utils = require("TreeFiddyGit.utils")

local M = {}

M.config = {
    change_directory_cmd = "cd",
}

-- TODO: Make a check if the current git repo is supported (bare repo, etc)

-- TODO: Flow for checking out remote branches and treeifying them
M.checkout_branch = function()
    -- Prompt the user for the branch name
    local branch_name = vim.fn.input("Enter the branch name: ")

    utils.git_branch_exists(branch_name, function(exists)
        if exists then
            vim.schedule(function()
                local path = vim.fn.input("Enter path to worktree (defaults to branch name): ")
                if path == "" then
                    path = branch_name
                end
                -- create a worktree for the existing branch
                M.create_git_worktree(branch_name, path, false)
            end)
        else
            print("Branch `" .. branch_name .. "` not found.")
        end
    end)
end

M.hello = function()
    print("Hello from TreeFiddyGit!")
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
                    callback(parsed_output)
                end)
            else
                error("Error running git worktree list")
            end
        end,
    }):start()
end

M.create_git_worktree = function(branch_name, path, is_new_branch)
    -- git fetch origin branch_name:branch_name
    -- git worktree add path branch_name
    local fetch_args = { "fetch", "origin", branch_name .. ":" .. branch_name }
    local worktree_args = { "worktree", "add", path, branch_name }

    Job:new({
        command = "git",
        args = fetch_args,
        on_exit = function(j, return_val)
            if return_val == 0 then
                print("Branch fetched successfully")
                Job:new({
                    command = "git",
                    args = worktree_args,
                    on_exit = function(j, return_val)
                        if return_val == 0 then
                            print("Worktree created successfully")
                        else
                            print("Error creating git worktree. Git error message:")
                            print(table.concat(j:stderr_result(), "\n"))
                        end
                    end,
                }):start()
            else
                print("Error fetching branch. Git error message:")
                print(table.concat(j:stderr_result(), "\n"))
            end
        end,
    }):start()
end

--- This function is called when a worktree is selected in the Telescope picker.
-- It changes the root directory in Neovim to the selected worktree and updates
-- the paths of all open buffers.
-- If a buffer's file does not exist in the new worktree, assume the user just
-- has a random file open and do nothing.
-- @param path The path of the selected worktree.
M.on_worktree_selected = function(path)
    utils.get_git_root_path(function(git_root)
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
