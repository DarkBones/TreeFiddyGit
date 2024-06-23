local path_utils = require("plenary.path")

local M = {}

M.make_relative = function(path, base)
    return path_utils.new(path):make_relative(base)
end

M._git_root_path = function()
    local handle = io.popen("git rev-parse --git-dir 2>/dev/null")
    if handle == nil then
        error("Failed to run `git rev-parse --git-dir`")
    end
    local result = handle:read("*a")
    handle:close()
    return result:match("^%s*(.-)%s*$") -- trim whitespace
end

M._get_pwd = function()
    local handle = io.popen("pwd")
    if handle == nil then
        error("Failed to run pwd")
    end
    local result = handle:read("*a")
    handle:close()
    return result:match("^%s*(.-)%s*$") -- trim whitespace
end

M.get_git_root_path = function()
    local root_path = M._git_root_path()

    if root_path == nil then
        error("Not in a git repository")
    end

    if root_path == "." then
        local pwd = M._get_pwd()

        if pwd:sub(-4) == ".git" then
            return pwd
        else
            error("Not in a git repository")
        end
    elseif root_path:find(".git/worktrees/") then
        -- remove the current branch from the path
        root_path = root_path:match("^(.+.git)/worktrees.*")
    elseif root_path == ".git" then
        error("Not in a supported git repository. Must be bare")
    end

    return root_path
end

M.update_buffer_path = function(new_path, current_buffer_path)
    local git_root = M.get_git_root_path()
    print("git_root: " .. git_root)
end

return M
