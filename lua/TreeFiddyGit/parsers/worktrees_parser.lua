local utils = require("TreeFiddyGit.utils")
local M = {}

local parse_worktree_line = function(worktree, max_name_length, max_path_length)
    local git_root = utils.get_git_root_path()
    if not git_root then
        error("Not a git repository or no access to the repository")
    end

    -- Split the worktree string into parts
    local parts = {}
    for part in string.gmatch(worktree, "%S+") do
        table.insert(parts, part)
    end

    if parts[2] and parts[3] then
        for part in string.gmatch(worktree, "%S+") do
            table.insert(parts, part)
        end

        -- Extract the worktree name, path, and commit hash
        local name = string.match(parts[3], "%[(.-)%]")
        local escaped_root = git_root:gsub("([^%w])", "%%%1")
        local path = string.gsub(parts[1], escaped_root, ".")

        local hash = parts[2]

        -- Adjust the max_path_length to account for the shortened path
        max_path_length = math.max(max_path_length - #git_root + 1, #path)

        -- Format the output to align the columns neatly
        return string.format("%-" .. max_name_length .. "s %-" .. max_path_length .. "s %s", name, path, hash)
    end
end

M.parse_worktrees = function(worktrees)
    local parsed_worktrees = {}
    local max_name_length = 0
    local max_path_length = 0

    -- Calculate the maximum length of each column
    for _, worktree in ipairs(worktrees) do
        local parts = {}
        for part in string.gmatch(worktree, "%S+") do
            table.insert(parts, part)
        end

        if parts[2] and parts[3] then
            local name = string.match(parts[3], "%[(.-)%]")
            local path = parts[1]

            max_name_length = math.max(max_name_length, #name)
            max_path_length = math.max(max_path_length, #path)
        end
    end

    -- Parse each worktree line with the calculated maximum lengths
    for _, worktree in ipairs(worktrees) do
        local parsed_worktree = parse_worktree_line(worktree, max_name_length, max_path_length)
        table.insert(parsed_worktrees, parsed_worktree)
    end
    return parsed_worktrees
end

return M
