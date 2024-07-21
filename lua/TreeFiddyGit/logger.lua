local M = {}

M.LogLevel = {
    INFO = "INFO",
    WARN = "WARN",
    ERROR = "ERROR",
    DEBUG = "DEBUG",
}

function M._get_config()
    return require("TreeFiddyGit").config.logging
end

M._log_level_order = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
}

function M._file_exists(fp)
    local file = io.open(fp, "r")
    if file then
        io.close(file)
        return true
    else
        return false
    end
end

function M._new_filename(old_file)
    local index = 1
    local new_file = old_file:gsub(".log$", "_" .. index .. ".log")

    while M._file_exists(new_file) do
        index = index + 1
        new_file = old_file:gsub(".log$", "_" .. index .. ".log")
    end

    return new_file
end

function M.log(level, initiator, msg)
    local config = M._get_config()
    if config.level == nil then
        return
    end

    if M._log_level_order[level] < M._log_level_order[config.level] then
        return
    end

    local date = os.date("%Y-%m-%dT%H:%M:%S")
    msg = vim.inspect(msg)
    local log_msg = date .. " -- " .. level .. " -- " .. initiator .. " -- " .. msg .. "\n"

    local file = io.open(config.file, "a")
    if file == nil then
        return
    end

    -- Check if file size is greater than or equal to max_filesize
    file:seek("end")
    local filesize = file:seek()
    if filesize >= config.max_size then
        file:close()
        if config.rolling_file then
            -- Remove top entries until file size is less than max_filesize
            local lines = {}
            file = io.open(config.file, "r")
            if file ~= nil then
                for line in file:lines() do
                    table.insert(lines, line)
                end
                file:close()
            end
            while #table.concat(lines, "\n") >= config.max_size do
                table.remove(lines, 1)
            end
            file = io.open(config.file, "w")
            if file ~= nil then
                file:write(table.concat(lines, "\n"))
                file:close()
            end
        else
            -- Rename the file
            local new_file = M._new_filename(config.file)
            os.rename(config.file, new_file)
            file = io.open(config.file, "w")
        end
    end

    if file ~= nil then
        file:write(log_msg)
        file:close()
    end
end

return M
