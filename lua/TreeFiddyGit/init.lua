local Job = require("plenary.job")
local telescope = require("telescope")
local worktree_parser = require("TreeFiddyGit.parsers.worktrees_parser")
local utils = require("TreeFiddyGit.utils")

local M = {}

M.config = {
    change_directory_cmd = "cd",
}

-- TODO: Make a check if the current git repo is supported (bare repo, etc)

M.hello = function()
    print("Hello from TreeFiddyGit!")
end

M.setup = function()
    require("telescope").load_extension("tree_fiddy_git")
end

M.get_git_worktrees = function(callback)
    Job:new({
        command = "git",
        args = { "worktree", "list" },
        on_exit = function(j, return_val)
            if return_val == 0 then
                local output = j:result()
                local parsed_output = worktree_parser.parse_worktrees(output)
                callback(parsed_output)
            else
                print("Error running git worktree list")
            end
        end,
    }):start()
end

M.on_worktree_selected = function(name, path)
    print("\n-------------------------\n")
    local git_root = utils.get_git_root_path()
    local full_path = git_root .. "/" .. utils.make_relative(path, ".")

    -- Change the directory of all open buffers
    local old_git_root = vim.fn.getcwd()
    print("old_git_root: " .. old_git_root)

    vim.cmd(M.config.change_directory_cmd .. " " .. full_path)

    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        local buf_path = vim.api.nvim_buf_get_name(bufnr)
        print("buf_path: " .. buf_path)

        local new_buf_path = buf_path:gsub(old_git_root, full_path)
        print("new_buf_path: " .. new_buf_path)

        -- check if the new path exists
        if vim.fn.filereadable(new_buf_path) == 1 then
            print("Changing buffer path to: " .. new_buf_path)
            vim.api.nvim_buf_set_name(bufnr, new_buf_path)
            vim.api.nvim_command("edit!")
        else
            print("File does not exist: " .. new_buf_path)
        end
    end
end

return M
