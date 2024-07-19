local M = {}

M.LogLevel = {
    INFO = "INFO",
    WARN = "WARN",
    ERROR = "ERROR",
    DEBUG = "DEBUG",
}

-- TODO: Make these configurable
local log_level = "DEBUG" -- Change this to set the log level
local log_file = vim.fn.stdpath("config") .. "/TreeFiddyGit.log"

local log_level_order = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
}

function M.log(level, initiator, msg)
    if log_level == nil then
        return
    end

    if log_level_order[level] < log_level_order[log_level] then
        return
    end

    local date = os.date("%Y-%m-%dT%H:%M:%S")
    if type(msg) == "table" then
        msg = vim.inspect(msg)
    end
    local log_msg = date .. " -- " .. level .. " -- " .. initiator .. " -- " .. msg .. "\n"

    local file = io.open(log_file, "a")
    if file == nil then
        return
    end

    file:write(log_msg)
    file:close()
end

return M
