local M = {}

M.LogLevel = {
    INFO = "INFO",
    WARN = "WARN",
    ERROR = "ERROR",
    DEBUG = "DEBUG",
}

local log_level = nil -- Change this to set the log level

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
    print(date .. " -- " .. level .. " -- " .. initiator .. " -- " .. msg)
end

return M
