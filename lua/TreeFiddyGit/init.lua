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

    -- Run the git command to list branches
    local git_branches = vim.fn.systemlist([[git worktree list --porcelain | awk '/^worktree/ {path=$2; sub(".*/", "", path); getline; branch=$2; sub(".*refs/heads/", "", branch); print path, $2, branch}' | grep -v ' (bare)$']])

    -- Create the Telescope picker
    pickers.new({}, {
        prompt_title = 'Git Branches',
        finder = finders.new_table {
            results = git_branches,
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
end

return M

