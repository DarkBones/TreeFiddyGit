local telescope = require("telescope")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local git_worktrees = require("TreeFiddyGit").get_git_worktrees

local tree_fiddy_git = function(opts)
    opts = opts or {}

    git_worktrees(function(worktrees)
        vim.schedule(function()
            pickers
                .new(opts, {
                    prompt_title = "Select Git Worktree",
                    finder = finders.new_table({
                        results = worktrees,
                    }),
                    sorter = sorters.get_generic_fuzzy_sorter(),
                    attach_mappings = function(prompt_bufnr, map)
                        actions.select_default:replace(function()
                            actions.close(prompt_bufnr)
                            local selection = action_state.get_selected_entry()
                            local message = vim.inspect(selection)
                            vim.api.nvim_echo({ { message } }, false, {})
                        end)
                        return true
                    end,
                })
                :find()
        end)
    end)
end

return telescope.register_extension({
    exports = {
        tree_fiddy_git = tree_fiddy_git,
    },
})
