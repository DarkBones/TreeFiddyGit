local telescope = require("telescope")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")

local tf = require("TreeFiddyGit")

local get_worktrees = function(opts)
    opts = opts or {}

    tf.get_worktrees(function(worktrees)
        vim.schedule(function()
            pickers
                .new(opts, {
                    prompt_title = "Select Git Worktree",
                    finder = finders.new_table({
                        results = worktrees,
                    }),
                    sorter = sorters.get_generic_fuzzy_sorter(),
                })
                :find()
        end)
    end)
end

return telescope.register_extension({
    exports = {
        get_worktrees = get_worktrees,
    },
})
