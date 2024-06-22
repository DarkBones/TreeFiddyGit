local telescope = require("telescope")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local tree_fiddy_git = function(opts)
    opts = opts or {}

    pickers
        .new(opts, {
            prompt_title = "Select Git Worktree",
            finder = finders.new_table({
                results = { "item1", "item2", "item3" },
            }),
            sorter = sorters.get_generic_fuzzy_sorter(),
            attach_mappings = function(prompt_bufnr, map)
                actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    print(vim.inspect(selection))
                    actions.close(prompt_bufnr)
                end)
                return true
            end,
        })
        :find()
end

return telescope.register_extension({
    exports = {
        tree_fiddy_git = tree_fiddy_git,
    },
})
