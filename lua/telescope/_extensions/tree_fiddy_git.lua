local telescope = require("telescope")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local tf = require("TreeFiddyGit")

local get_worktrees = function(opts)
    opts = opts or {}

    tf.get_git_worktrees(function(worktrees)
        vim.schedule(function()
            pickers
                .new(opts, {
                    prompt_title = "Select Git Worktree",
                    finder = finders.new_table({
                        results = worktrees,
                    }),
                    sorter = sorters.get_generic_fuzzy_sorter(),
                    attach_mappings = function(prompt_bufnr, _)
                        actions.select_default:replace(function()
                            actions.close(prompt_bufnr)
                            local selection = action_state.get_selected_entry()
                            local message = selection[1]
                            local _, wt_path = message:match("([^%s]+)%s+([^%s]+)")
                            tf.on_worktree_selected(wt_path)
                        end)
                        return true
                    end,
                })
                :find()
        end)
    end)
end

local create_worktree = function(opts)
    opts = opts or {}

    tf.get_git_worktrees(function(worktrees)
        vim.schedule(function()
            pickers
                .new(opts, {
                    prompt_title = "Create Git Worktree",
                    finder = finders.new_table({
                        results = worktrees,
                    }),
                    sorter = sorters.get_generic_fuzzy_sorter(),
                    attach_mappings = function(prompt_bufnr, _)
                        actions.select_default:replace(function()
                            actions.close(prompt_bufnr)
                            local branch_name = action_state.get_current_line()
                            if branch_name == "" then
                                return
                            end

                            local path = vim.fn.input("Enter path to worktree (defaults to " .. branch_name .. "): ")

                            if path == "" then
                                path = branch_name
                            end
                            tf.create_git_worktree(branch_name, path)
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
        get_worktrees = get_worktrees,
        create_worktree = create_worktree,
    },
})
