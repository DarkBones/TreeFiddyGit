local Job = require("plenary.job")
local telescope = require("telescope")

local M = {}

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
                local parsed_output = require("TreeFiddyGit.parsers.worktrees_parser").parse_worktrees(output)
                callback(parsed_output)
            else
                print("Error running git worktree list")
            end
        end,
    }):start()
end

return M
