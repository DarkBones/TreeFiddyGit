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
            utils._get_git_worktree_reference = function(callback)
                vim.schedule(function()
                    callback("/home/user/gitrepo.git/worktrees/main")
                end)
            end

            utils.get_git_root_path(function(root_path)
                assert.are.equal("/home/user/gitrepo.git", root_path)
            end)
        end)

        it("should handle multiple '.git' instances in the path", function()
            utils._get_git_worktree_reference = function(callback)
                vim.schedule(function()
                    callback("/home/user.git/gitrepo.git/worktrees/main")
                end)
            end

            utils.get_git_root_path(function(root_path)
                assert.are.equal("/home/user.git/gitrepo.git", root_path)
            end)
        end)

        it("should handle a worktree having '.git' in the path", function()
            utils._get_git_worktree_reference = function(callback)
                vim.schedule(function()
                    callback("/home/user/gitrepo.git/worktrees/main.git")
                end)
            end

            utils.get_git_root_path(function(root_path)
                assert.are.equal("/home/user/gitrepo.git", root_path)
            end)
        end)

        it("should handle multiple '.git/worktrees' in the path", function()
            utils._get_git_worktree_reference = function(callback)
                vim.schedule(function()
                    callback("/home/user/gitrepo.git/worktrees/main.git/worktrees/main")
                end)
            end

            utils.get_git_root_path(function(root_path)
                assert.are.equal("/home/user/gitrepo.git/worktrees/main.git", root_path)
            end)
        end)

        it("should handle being in the bare repo", function()
            utils._get_git_worktree_reference = function(callback)
                vim.schedule(function()
                    callback(".")
                end)
            end

            utils._get_pwd = function(callback)
                vim.schedule(function()
                    callback("/home/user/gitrepo.git")
                end)
            end

            utils.get_git_root_path(function(root_path)
                assert.are.equal("/home/user/gitrepo.git", root_path)
            end)
        end)

        it("should fail when in a treeless repo", function()
            utils._get_git_worktree_reference = function(callback)
                vim.schedule(function()
                    callback(".git")
                end)
            end

            utils.get_git_root_path(function(output)
                assert.has_error(output)
            end)
        end)

        it("should fail when not in a supported repo", function()
            utils._get_git_worktree_reference = function(callback)
                vim.schedule(function()
                    callback(nil)
                end)
            end

            utils.get_git_root_path(function(output)
                assert.has_error(function()
                    utils.get_git_root_path()
                end)
            end)
        end)

        it("should handle when git root path is a subdirectory of the current directory", function()
            utils._get_git_worktree_reference = function(callback)
                vim.schedule(function()
                    callback("./subdirectory/.git")
                end)
            end

            utils.get_git_root_path(function(root_path)
                assert.are.equal("./subdirectory/.git", root_path)
            end)
        end)

        it("should handle when git root path is a relative path", function()
            utils._get_git_worktree_reference = function(callback)
                vim.schedule(function()
                    callback("./relative/path/.git")
                end)
            end

            utils.get_git_root_path(function(root_path)
                assert.are.equal("./relative/path/.git", root_path)
            end)
        end)

        it("should handle when worktree is named 'sometree.git'", function()
            utils._get_git_worktree_reference = function(callback)
                vim.schedule(function()
                    callback("/home/user/gitrepo.git/worktrees/sometree.git")
                end)
            end

            utils.get_git_root_path(function(root_path)
                assert.are.equal("/home/user/gitrepo.git", root_path)
            end)
        end)
    end)
    --
    describe("update_file_path_to_new_worktree()", function()
        it("should return the new filepath", function()
            local old_git_path = "/home/user/gitrepo.git/main/nested/tree"
            local new_git_path = "/home/user/gitrepo.git/feature-a"
            local buf_path = "/home/user/gitrepo.git/main/nested/tree/app/some/nested/file.txt"

            local new_path = utils.update_worktree_buffer_path(old_git_path, new_git_path, buf_path)
            assert.are.equal("/home/user/gitrepo.git/feature-a/app/some/nested/file.txt", new_path)
        end)

        it("should return nil when the buffer path is outside the git repo", function()
            local old_git_path = "/home/user/gitrepo.git/main/nested/tree"
            local new_git_path = "/home/user/gitrepo.git/feature-a"
            local buf_path = "/home/user/otherrepo.git/main/nested/tree/app/some/nested/file.txt"

            local new_path = utils.update_worktree_buffer_path(old_git_path, new_git_path, buf_path)
            assert.is_nil(new_path)
        end)

        it("should handle when the new path and old path are the same", function()
            local old_git_path = "/home/user/gitrepo.git/main/nested/tree"
            local new_git_path = "/home/user/gitrepo.git/main/nested/tree"
            local buf_path = "/home/user/gitrepo.git/main/nested/tree/app/some/nested/file.txt"

            local new_path = utils.update_worktree_buffer_path(old_git_path, new_git_path, buf_path)
            assert.are.equal("/home/user/gitrepo.git/main/nested/tree/app/some/nested/file.txt", new_path)
        end)

        it("should handle when the old path is a substring of the new path", function()
            local old_git_path = "/home/user/gitrepo.git/main/nested/tree"
            local new_git_path = "/home/user/gitrepo.git/main/nested/tree/feature-a"
            local buf_path = "/home/user/gitrepo.git/main/nested/tree/app/some/nested/file.txt"

            local new_path = utils.update_worktree_buffer_path(old_git_path, new_git_path, buf_path)
            assert.are.equal("/home/user/gitrepo.git/main/nested/tree/feature-a/app/some/nested/file.txt", new_path)
        end)

        it("should handle when the old path is a superstring of the new path", function()
            local old_git_path = "/home/user/gitrepo.git/main/nested/tree"
            local new_git_path = "/home/user/gitrepo.git/main"
            local buf_path = "/home/user/gitrepo.git/main/nested/tree/app/some/nested/file.txt"

            local new_path = utils.update_worktree_buffer_path(old_git_path, new_git_path, buf_path)
            assert.are.equal("/home/user/gitrepo.git/main/app/some/nested/file.txt", new_path)
        end)

        it("handles edge case where old, new, and buf path are all identical", function()
            local old_git_path = "/home/user/gitrepo.git/main/nested/tree"
            local new_git_path = "/home/user/gitrepo.git/main/nested/tree"
            local buf_path = "/home/user/gitrepo.git/main/nested/tree"

            local new_path = utils.update_worktree_buffer_path(old_git_path, new_git_path, buf_path)
            assert.are.equal("/home/user/gitrepo.git/main/nested/tree", new_path)
        end)
    end)
end)
