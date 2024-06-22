local M = {}

M.get_git_root_path = function()
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

return M
