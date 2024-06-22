local telescope = require("telescope")

local M = {}

M.hello = function()
    print("Hello from TreeFiddyGit!")
end

M.setup = function()
    require("telescope").load_extension("tree_fiddy_git")
end

M.get_git_worktrees = function()
    return { "main", "feature-a", "someotherbranch", "these-are-hard-coded-btw" }
end

return M
