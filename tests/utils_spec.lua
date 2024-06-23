---@diagnostic disable: duplicate-set-field

local assert = require("luassert")

describe("utils", function()
    local utils = require("TreeFiddyGit.utils")
    describe("get_git_root_path()", function()
        local original_git_root_path = utils._get_git_worktree_reference

        after_each(function()
            utils._get_git_worktree_reference = original_git_root_path
        end)

        it("should return the git root path when inside a worktree", function()
            utils._get_git_worktree_reference = function()
                return "/home/user/gitrepo.git/worktrees/main"
            end

            local root_path = utils.get_git_root_path()
            assert.are.equal("/home/user/gitrepo.git", root_path)
        end)

        it("should handle multiple '.git' instances in the path", function()
            utils._get_git_worktree_reference = function()
                return "/home/user.git/gitrepo.git/worktrees/main"
            end

            local root_path = utils.get_git_root_path()
            assert.are.equal("/home/user.git/gitrepo.git", root_path)
        end)

        it("should handle a worktree having '.git' in the path", function()
            utils._get_git_worktree_reference = function()
                return "/home/user/gitrepo.git/worktrees/main.git"
            end

            local root_path = utils.get_git_root_path()
            assert.are.equal("/home/user/gitrepo.git", root_path)
        end)

        it("should handle multiple '.git/worktrees' in the path", function()
            utils._get_git_worktree_reference = function()
                return "/home/user/gitrepo.git/worktrees/main.git/worktrees/main"
            end

            local root_path = utils.get_git_root_path()
            assert.are.equal("/home/user/gitrepo.git/worktrees/main.git", root_path)
        end)

        it("should handle being in the bare repo", function()
            utils._get_git_worktree_reference = function()
                return "."
            end

            utils._get_pwd = function()
                return "/home/user/gitrepo.git"
            end

            local root_path = utils.get_git_root_path()
            assert.are.equal("/home/user/gitrepo.git", root_path)
        end)

        it("should fail when in a treeless repo", function()
            utils._get_git_worktree_reference = function()
                return ".git"
            end

            assert.has_error(function()
                utils.get_git_root_path()
            end)
        end)

        it("should fail when not in a supported repo", function()
            utils._get_git_worktree_reference = function()
                return nil
            end

            assert.has_error(function()
                utils.get_git_root_path()
            end)
        end)

        it("should handle when git root path is a subdirectory of the current directory", function()
            utils._get_git_worktree_reference = function()
                return "./subdirectory/.git"
            end

            local root_path = utils.get_git_root_path()
            assert.are.equal("./subdirectory/.git", root_path)
        end)

        it("should handle when git root path is a relative path", function()
            utils._get_git_worktree_reference = function()
                return "./relative/path/.git"
            end

            local root_path = utils.get_git_root_path()
            assert.are.equal("./relative/path/.git", root_path)
        end)

        it("should handle when worktree is named 'sometree.git'", function()
            utils._get_git_worktree_reference = function()
                return "/home/user/gitrepo.git/worktrees/sometree.git"
            end

            local root_path = utils.get_git_root_path()
            assert.are.equal("/home/user/gitrepo.git", root_path)
        end)
    end)

    describe("update_file_path_to_new_worktree()", function()
        it("should return the new filepath", function()
            -- git_root:    /Users/basdonker/Developer/git-playground-delete-me.git
            -- full_path:   /Users/basdonker/Developer/git-playground-delete-me.git/feature-a
            -- old_path:    /Users/basdonker/Developer/git-playground-delete-me.git/main/nestedtree

            -- buf_path:    /Users/basdonker/Developer/git-playground-delete-me.git/main/nestedtree/app/controllers/home_controller.rb
        end)
    end)
end)
