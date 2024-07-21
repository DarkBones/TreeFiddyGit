local telescope = require("telescope")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local tf = require("TreeFiddyGit")
local logger = require("TreeFiddyGit.logger")
local parsers = require("TreeFiddyGit.parsers")

local function parse_selection(selection)
    return selection[1]:match("([^%s]+)%s+([^%s]+)")
end

local self_name = "telescope/_extensions/tree_fiddy_git"

local function get_worktrees(opts)
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
                    attach_mappings = function(prompt_bufnr, map)
                        actions.select_default:replace(function()
                            actions.close(prompt_bufnr)
                            local selection = action_state.get_selected_entry()
                            local branch_name, path = parse_selection(selection)

                            logger.log(
                                logger.LogLevel.DEBUG,
                                self_name,
                                "worktree selection made: " .. vim.inspect({ branch_name, path })
                            )

                            tf.move_to_worktree(branch_name, path)
                        end)

                        map("i", "<C-d>", function()
                            logger.log(
                                logger.LogLevel.DEBUG,
                                self_name,
                                "Delete worktree action triggered on selection: "
                                    .. vim.inspect(action_state.get_selected_entry())
                            )

                            local selection = action_state.get_selected_entry()
                            if selection then
                                vim.ui.select({ "Yes", "No" }, {
                                    prompt = "Are you sure you want to delete this worktree?",
                                }, function(choice)
                                    if choice == "Yes" then
                                        logger.log(
                                            logger.LogLevel.DEBUG,
                                            self_name,
                                            "Deleting worktree: " .. vim.inspect(selection)
                                        )
                                        local branch_name, path = parse_selection(selection)
                                        tf.delete_worktree(branch_name, path)
                                    end
                                end)
                            end
                        end)

                        return true
                    end,
                })
                :find()
        end)
    end)
end

local function create_worktree(opts, stash)
    opts = opts or {}
    if stash == nil then
        stash = false
    end

    local title = "Create Git Worktree"
    if stash then
        title = "Create Git Worktree with Stash"
    end

    tf.get_worktrees(function(worktrees)
        vim.schedule(function()
            pickers
                .new(opts, {
                    prompt_title = title,
                    finder = finders.new_table({
                        results = worktrees,
                    }),
                    sorter = sorters.get_generic_fuzzy_sorter(),
                    attach_mappings = function(prompt_bufnr)
                        actions.select_default:replace(function()
                            actions.close(prompt_bufnr)
                            local branch_name = action_state.get_current_line()
                            if branch_name == "" then
                                return
                            end

                            logger.log(
                                logger.LogLevel.DEBUG,
                                self_name,
                                "Create worktree with branch_name: " .. vim.inspect(branch_name)
                            )

                            local parsed_branch_name = nil
                            if tf.config.branch_parser then
                                parsed_branch_name = tf.config.branch_parser(branch_name)
                                logger.log(
                                    logger.LogLevel.DEBUG,
                                    self_name,
                                    "Parsed branch name with custom parser: " .. vim.inspect(parsed_branch_name)
                                )
                            else
                                parsed_branch_name = parsers.parse_branch_name(branch_name)
                                logger.log(
                                    logger.LogLevel.DEBUG,
                                    self_name,
                                    "Parsed branch name with default parser: " .. vim.inspect(parsed_branch_name)
                                )
                            end

                            local path = vim.fn.input("Enter path to worktree (defaults to branch name): ")

                            if path == "" then
                                path = branch_name
                            end

                            local parsed_path = nil
                            if tf.config.path_parser then
                                parsed_path = tf.config.path_parser(path)
                                logger.log(
                                    logger.LogLevel.DEBUG,
                                    self_name,
                                    "Parsed path with custom parser: " .. vim.inspect(parsed_path)
                                )
                            else
                                parsed_path = parsers.parse_path(path)
                                logger.log(
                                    logger.LogLevel.DEBUG,
                                    self_name,
                                    "Parsed path with default parser: " .. vim.inspect(parsed_path)
                                )
                            end

                            if stash then
                                tf.create_new_worktree_with_stash(parsed_branch_name, parsed_path)
                            else
                                tf.create_new_worktree(parsed_branch_name, parsed_path)
                            end
                        end)

                        return true
                    end,
                })
                :find()
        end)
    end)
end

local function create_worktree_stash(opts)
    create_worktree(opts, true)
end

return telescope.register_extension({
    exports = {
        get_worktrees = get_worktrees,
        create_worktree = create_worktree,
        create_worktree_stash = create_worktree_stash,
    },
})
