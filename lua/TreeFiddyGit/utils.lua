local logger = require("TreeFiddyGit.logger")
local path_utils = require("plenary.path")

local M = {}

function M.make_relative(path, base)
    return path_utils.new(path):make_relative(base)
end

function M._is_absolute_path(path)
    logger.log(logger.LogLevel.DEBUG, "utils._is_absolute_path", "called with: " .. vim.inspect(path))

    if path:sub(1, 1) == "/" then
        logger.log(logger.LogLevel.INFO, "utils._is_absolute_path", "starts with '/', so true")
        return true
    end

    -- Windows
    local windows_root = path:match("^%a:[/\\]")

    if windows_root == nil then
        logger.log(logger.LogLevel.INFO, "utils._is_absolute_path", "does not start with windows root, so false")
        return false
    else
        logger.log(logger.LogLevel.INFO, "utils._is_absolute_path", "starts with windows root, so true")
        return true
    end
end

function M._make_absolute(root, path)
    local self_name = "utils.make_absolute"
    logger.log(logger.LogLevel.DEBUG, self_name, "called with: " .. vim.inspect({ root, path }))

    if M._is_absolute_path(path) then
        logger.log(logger.LogLevel.INFO, self_name, "Given `path` is already absolute")
        return path
    end

    if not M._is_absolute_path(root) then
        logger.log(logger.LogLevel.WARN, "utils.make_absolute", "Given `root` is not absolute")
    end

    local separator = "/"
    if root:match("^%a:\\") then
        logger.log(logger.LogLevel.DEBUG, self_name, "Windows root detected")
        separator = "\\"
    end

    if root:sub(-1) == "/" or root:sub(-1) == "\\" then
        logger.log(logger.LogLevel.DEBUG, self_name, "Removing trailing separator from root")
        root = root:sub(1, -2)
    end

    if path:sub(1, 2) == "./" or path:sub(1, 2) == ".\\" then
        logger.log(logger.LogLevel.DEBUG, self_name, "Removing './' from path")
        path = path:sub(3)
    end

    local abs_path = root .. separator .. path
    logger.log(logger.LogLevel.DEBUG, self_name, "resulting abs_path: " .. abs_path)

    if separator == "/" then
        abs_path = abs_path:gsub("[^/\\]+", function(part)
            logger.log(logger.LogLevel.DEBUG, self_name, "Replacing '\\' with '\\\\'")
            return part:gsub("\\", "\\\\")
        end)
    end

    logger.log(logger.LogLevel.INFO, self_name, "Returning: " .. abs_path)
    return abs_path
end

function M.get_absolute_wt_path(rel_path, callback)
    logger.log(logger.LogLevel.DEBUG, "utils.get_absolute_wt_path", "called with: " .. vim.inspect(rel_path))

    require("TreeFiddyGit.jobs").get_git_root_path(function(git_root, err_git_root)
        if err_git_root ~= nil then
            callback(nil, err_git_root)
            return
        end

        local abs_path = M._make_absolute(git_root, rel_path)
        logger.log(logger.LogLevel.INFO, "utils.get_absolute_wt_path", "Returning: " .. abs_path)

        callback(abs_path, nil)
    end)
end

function M.deep_merge(base_table, new_table)
    for k, v in pairs(new_table) do
        if type(v) == "table" and type(base_table[k]) == "table" then
            M.deep_merge(base_table[k], v)
        else
            base_table[k] = v
        end
    end
    return base_table
end

function M.merge_hook_path(path, hook)
    return path and (path .. "." .. hook) or hook
end

function M.run_hook(action, data)
    logger.log(logger.LogLevel.DEBUG, "utils.run_hook", "called with: " .. vim.inspect({ action, data }))

    local hook = require("TreeFiddyGit").config.hook

    if hook == nil then
        logger.log(logger.LogLevel.DEBUG, "utils.run_hook", "No hook defined")
        return
    end

    if type(hook) == "string" then
        logger.log(logger.LogLevel.INFO, "utils.run_hook", "Hook is a string, so running as a command")
        os.execute(hook)
    elseif type(hook) == "function" then
        logger.log(
            logger.LogLevel.INFO,
            "utils.run_hook",
            "Hook is a function, so running it with path '" .. vim.inspect(hook_path) .. "'"
        )
        hook(action, data)
    end
end

function M.update_worktree_buffer_path(old_git_path, new_git_path, buf_path)
    logger.log(
        logger.LogLevel.DEBUG,
        "utils.update_worktree_buffer_path",
        "called with: " .. vim.inspect({ old_git_path, new_git_path, buf_path })
    )

    if buf_path:sub(1, #old_git_path) ~= old_git_path then
        logger.log(
            logger.LogLevel.ERROR,
            "utils.update_worktree_buffer_path",
            "Buffer path does not start with old git path"
        )
        return buf_path
    end

    local buf_relative_path = buf_path:sub(#old_git_path + 1)
    logger.log(
        logger.LogLevel.INFO,
        "utils.update_worktree_buffer_path",
        "Returning: " .. new_git_path .. buf_relative_path
    )

    return new_git_path .. buf_relative_path
end

return M
