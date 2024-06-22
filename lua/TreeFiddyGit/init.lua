local Job = require("plenary.job")
local telescope = require("telescope")
local worktree_parser = require("TreeFiddyGit.parsers.worktrees_parser")

local function is_bare_repo(callback)
    Job:new({
        command = "git",
        args = { "rev-parse", "--is-bare-repository" },
        on_exit = function(j, return_val)
            if return_val == 0 then
                local output = j:result()
                if output[1] == "false" then
                    print("Not a bare repository. Please use a bare repository.")
                    callback(false)
                else
                    callback(true)
                end
            else
                print("Error running git rev-parse --is-bare-repository")
                callback(false)
            end
        end,
    }):start()
end

local M = {}

M.hello = function()
    print("Hello from TreeFiddyGit!")
end

M.setup = function()
    require("telescope").load_extension("tree_fiddy_git")
end

M.get_git_worktrees = function(callback)
    is_bare_repo(function(is_bare)
        if not is_bare then
            return
        end
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
    end)
end

return M
