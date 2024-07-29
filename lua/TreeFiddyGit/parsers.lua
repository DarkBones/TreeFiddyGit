local jobs = require("TreeFiddyGit.jobs")
local utils = require("TreeFiddyGit.utils")

local M = {}

function M._parse_worktree_line(worktree, max_name_length, max_path_length, git_root)
    -- Split the worktree string into parts
    local parts = {}
    for part in string.gmatch(worktree, "%S+") do
        table.insert(parts, part)
    end

    -- Only parse lines with all 3 parts, to avoid including the bare repo
    if parts[3] then
        -- Extract the worktree name, path, and commit hash
        local name = string.match(parts[3], "%[(.-)%]")
        local path = "./" .. utils.make_relative(parts[1], git_root)
        local hash = parts[2]

        -- Adjust the max_path_length to account for the shortened path
        max_path_length = math.max(max_path_length - #git_root + 1, #path)

        -- Format the output to align the columns neatly
        return string.format("%-" .. max_name_length .. "s %-" .. max_path_length .. "s %s", name, path, hash)
    end
end

function M.parse_worktrees(worktrees, callback)
    local parsed_worktrees = {}
    local max_name_length = 0
    local max_path_length = 0

    jobs.get_git_root_path(function(root_path, root_path_err)
        if root_path_err ~= nil then
            callback(nil, root_path_err)
            return
        end

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
            local parsed_worktree = M._parse_worktree_line(worktree, max_name_length, max_path_length, root_path)
            table.insert(parsed_worktrees, parsed_worktree)
        end

        callback(parsed_worktrees, nil)
    end)
end

function M.parse_branch_name(branch_name)
    -- Remove any leading or trailing whitespace
    branch_name = branch_name:match("^%s*(.-)%s*$")

    -- Replace invalid characters with hyphens
    branch_name = branch_name:gsub("[^%w%-_.]", "-")

    return branch_name
end

function M.parse_path(path)
    -- Remove any leading or trailing whitespace
    path = path:match("^%s*(.-)%s*$")

    -- Replace backslashes with forward slashes for consistency
    path = path:gsub("\\", "/")

    -- Replace non-alphanumeric characters (except for '/') with hyphens
    path = path:gsub("[^%w/]", "-")

    -- Replace spaces with hyphens
    path = path:gsub("%s+", "-")

    -- Remove repeating slashes
    path = path:gsub("/+", "/")

    -- Remove leading and trailing slashes
    path = path:gsub("^/*", ""):gsub("/*$", "")

    return path
end

return M
