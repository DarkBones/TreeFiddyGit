local Job = require("plenary.job")
local telescope = require("telescope")
local worktree_parser = require("TreeFiddyGit.parsers.worktrees_parser")
local utils = require("TreeFiddyGit.utils")

local M = {}

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
    print("Name: " .. name)
    print("Path: " .. path)

    local git_root = utils.get_git_root_path()
    -- local full_path = git_root .. "/" .. path:sub(3)
    local full_path = git_root .. "/" .. utils.make_relative(path, ".")

    print("Full path: " .. full_path)

    -- vim.cmd("cd ." .. path)
end

return M
