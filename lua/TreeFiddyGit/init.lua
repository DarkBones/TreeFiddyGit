local M = {}

-- Function to print a hello message
M.hello = function()
    print("Hello from TreeFiddyGit!")
end

-- Function to list all local git branches
M.list_branches = function()
    local has_telescope, telescope = pcall(require, 'telescope')

    if not has_telescope then
        error("This plugin requires Telescope.nvim")
    end

    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local sorters = require('telescope.sorters')
    local actions = require('telescope.actions')
    local action_state = require('telescope.actions.state')
    local Job = require('plenary.job')

    -- Run the git command to list branches
    local git_worktrees = {}
    Job:new({
        command = 'git',
        args = {'worktree', 'list', '--porcelain'},
        on_stdout = function(_, data)
            if data:find("^worktree") then
                local path = data:match("^worktree (.*)")
                local name = path:match(".*/(.*).git")
                table.insert(git_worktrees, {name = name, path = path})
            elseif data:find("^HEAD") then
                local commit = data:match("^HEAD (.*)")
                git_worktrees[#git_worktrees].commit = commit:sub(1, 7)
            elseif data:find("^branch") then
                local branch = data:match("^branch refs/heads/(.*)")
                git_worktrees[#git_worktrees].branch = branch
            end
        end,
        on_exit = vim.schedule_wrap(function()
            -- Format the worktrees into a list of strings
            local worktrees = {}
            for _, worktree in ipairs(git_worktrees) do
                if worktree.branch then
                    table.insert(worktrees, string.format("[%-15s] %-20s %s", worktree.branch, worktree.name, worktree.commit))
                end
            end

            -- Create the Telescope picker
            pickers.new({}, {
                prompt_title = 'Git Branches',
                finder = finders.new_table {
                    results = worktrees,
                },
                sorter = sorters.get_generic_fuzzy_sorter(),
                attach_mappings = function(_, map)
                    map('i', '<CR>', function(prompt_bufnr)
                        local selection = action_state.get_selected_entry()
                        actions.close(prompt_bufnr)
                        print('You selected: ' .. selection[1])
                    end)
                    return true
                end,
            }):find()
        end),
    }):start()
end

return M

