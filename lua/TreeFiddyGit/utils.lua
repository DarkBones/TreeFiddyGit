local path_utils = require("plenary.path")

local M = {}

M.make_relative = function(path, base)
    return path_utils.new(path):make_relative(base)
end

--- This function returns a reference to the current git worktree.
-- The returned reference is in the format `path/to/gitrepo.git/worktrees/worktree_name`,
-- where `worktree_name` is the name of the current worktree.
-- The format is always gitrepo.git/worktrees/worktree_name, even if the worktree
-- is deeply nested in other worktrees.
-- @return string: A reference to the current git worktree.
M._get_git_worktree_reference = function()
    local handle = io.popen("git rev-parse --git-dir 2>/dev/null")
    if handle == nil then
        error("Failed to run `git rev-parse --git-dir`")
    end
    local result = handle:read("*a")
    handle:close()
    return result:match("^%s*(.-)%s*$") -- trim whitespace
end

--- This function returns the current working directory.
-- @return string: The current working directory.
M._get_pwd = function()
    local handle = io.popen("pwd")
    if handle == nil then
        error("Failed to run pwd")
    end
    local result = handle:read("*a")
    handle:close()
    return result:match("^%s*(.-)%s*$") -- trim whitespace
end

--- This function returns the actual path of the current git worktree.
-- The returned path is the root path of the current worktree, regardless of
-- how deeply nested the current directory is within the worktree.
-- @return string: The path of the current git worktree.
M.get_git_path = function()
    local handle = io.popen("git rev-parse --show-toplevel 2>/dev/null")
    if handle == nil then
        error("Failed to run `git rev-parse --show-toplevel`")
    end
    local result = handle:read("*a")
    handle:close()
    return result:match("^%s*(.-)%s*$") -- trim whitespace
end

--- This function returns the root path of the current git repository.
-- No matter where the command is run from, it will always get the root path of the git repository.
-- If a tree is nested in another tree, it won't affect the result.
-- If a user is in some deeply nested directory, it will still only return the root path
-- If the current directory is not a supported (bare) git repository, it throws an error.
-- @return string: The root path of the current git repository.
M.get_git_root_path = function()
    local root_path = M._get_git_worktree_reference()

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

M.update_worktree_buffer_path = function(old_git_path, new_git_path, buf_path)
    -- old_git_path:    /Users/basdonker/Developer/git-playground-delete-me.git/main/nestedtree
    -- new_git_path:    /Users/basdonker/Developer/git-playground-delete-me.git/feature-a
    -- buf_path:        /Users/basdonker/Developer/git-playground-delete-me.git/main/nestedtree/app/controllers/home_controller.rb

    -- output:          /Users/basdonker/Developer/git-playground-delete-me.git/feature-a/app/controllers/home_controller.rb
    --
    -- Plan:
    -- 1. Remove old_path from buf_path to make buf_relative_path
    -- 2. Concat new_path with buf_relative_path to make new_buf_path
    -- local git_root = M.get_git_root_path()
    -- print("git_root: " .. git_root)

    if buf_path:sub(1, #old_git_path) ~= old_git_path then
        return nil
    end

    local buf_relative_path = buf_path:sub(#old_git_path + 1)

    return new_git_path .. buf_relative_path
end

return M
