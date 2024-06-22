local Job = require("plenary.job")
local telescope = require("telescope")

local M = {}

M.hello = function()
    print("Hello from TreeFiddyGit!")
end

M.setup = function()
    require("telescope").load_extension("tree_fiddy_git")
end

-- local parse_worktrees = function(worktrees)
--     local parsed_worktrees = {}
--
--     for _, worktree in ipairs(worktrees) do
--         local path, hash, branch = worktree:match("(.-)%s+(%w+)%s+%[(.*)%]")
--         if path and hash and branch then
--             table.insert(parsed_worktrees, { path = path, hash = hash, branch = branch })
--         else
--             -- Handle the case where the worktree is bare and doesn't have a hash or branch
--             local path = worktree:match("(.-)%s+%((.*)%)")
--             if path then
--                 table.insert(parsed_worktrees, { path = path, hash = "", branch = "" })
--             end
--         end
--     end
--
--     return parsed_worktrees
-- end

M.get_git_worktrees = function(callback)
    Job:new({
        command = "git",
        args = { "worktree", "list" },
        on_exit = function(j, return_val)
            if return_val == 0 then
                local output = j:result()
                -- local parsed_output = parse_worktrees(output)
                local parsed_output = require("TreeFiddyGit.parsers.worktrees_parser").parse_worktrees(output)
                callback(parsed_output)
            else
                print("Error running git worktree list")
            end
        end,
    }):start()
end

return M
