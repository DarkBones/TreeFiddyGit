local M = {}

local function get_git_root_path()
    local handle = io.popen("git rev-parse --show-toplevel 2>/dev/null")
    if handle == nil then
        error("Failed to run git rev-parse --show-toplevel")
    end
    local result = handle:read("*a")
    handle:close()
    result = result:match("^%s*(.-)%s*$") -- trim whitespace

    if result == "" then
        local pwd_handle = io.popen("pwd")
        if pwd_handle == nil then
            error("Failed to run pwd")
        end

        local pwd = pwd_handle:read("*a")
        pwd_handle:close()
        pwd = pwd:match("^%s*(.-)%s*$") -- trim whitespace

        if pwd:sub(-4) == ".git" then
            return pwd
        else
            error("Not in a git repository")
        end
    else
        -- remove the current branch from the path
        return result:match("^(.+)/[^/]+$")
    end
end

local parse_worktree_line = function(worktree)
    local git_root = get_git_root_path()
    if not git_root then
        error("Not a git repository or no access to the repository")
    end

    -- Split the worktree string into parts
    local parts = {}
    for part in string.gmatch(worktree, "%S+") do
        table.insert(parts, part)
    end

    if parts[2] and parts[3] then
        print(parts)
        for part in string.gmatch(worktree, "%S+") do
            table.insert(parts, part)
        end

        -- Extract the worktree name, path, and commit hash
        local name = string.match(parts[3], "%[(.-)%]")
        local escaped_root = git_root:gsub("([^%w])", "%%%1")
        local path = string.gsub(parts[1], escaped_root, ".")

        local hash = parts[2]

        -- Format the output to align the columns neatly
        return string.format("%-30s %-60s %s", name, path, hash)
    end
end

M.parse_worktrees = function(worktrees)
    local parsed_worktrees = {}
    for _, worktree in ipairs(worktrees) do
        local parsed_worktree = parse_worktree_line(worktree)
        table.insert(parsed_worktrees, parsed_worktree)
    end
    return parsed_worktrees
end

return M
