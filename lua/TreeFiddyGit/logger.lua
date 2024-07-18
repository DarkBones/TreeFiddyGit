local M = {}

M.LogLevel = {
    INFO = "INFO",
    WARN = "WARN",
    ERROR = "ERROR",
    DEBUG = "DEBUG"
}

function M.log(level, initiator, msg)
    local date = os.date("%Y-%m-%dT%H:%M:%S")
    if type(msg) == "table" then
        msg = vim.inspect(msg)
    end
    print(date .. " -- " .. level .. " -- " .. initiator .. " -- " .. msg)
end

return M
