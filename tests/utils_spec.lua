---@diagnostic disable: duplicate-set-field

local async = require("plenary.async.tests")
local assert = require("luassert")

describe("utils", function()
    local utils = require("TreeFiddyGit.utils")
    describe("get_git_root_path()", function()
        local original_git_root_path = utils._git_root_path

        after_each(function()
            utils._git_root_path = original_git_root_path
        end)

        it("should return the git root path when inside a worktree", function()
            utils._git_root_path = function()
                return "/home/user/gitrepo.git/worktrees/main"
            end

            local root_path = utils.get_git_root_path()
            assert.are.equal("/home/user/gitrepo.git", root_path)
        end)

        it("should handle multiple '.git' instances in the path", function()
            utils._git_root_path = function()
                return "/home/user.git/gitrepo.git/worktrees/main"
            end

            local root_path = utils.get_git_root_path()
            assert.are.equal("/home/user.git/gitrepo.git", root_path)
        end)

        it("should handle a worktree having '.git' in the path", function()
            utils._git_root_path = function()
                return "/home/user/gitrepo.git/worktrees/main.git"
            end

            local root_path = utils.get_git_root_path()
            assert.are.equal("/home/user/gitrepo.git", root_path)
        end)

        it("should handle multiple '.git/worktrees' in the path", function()
            utils._git_root_path = function()
                return "/home/user/gitrepo.git/worktrees/main.git/worktrees/main"
            end

            local root_path = utils.get_git_root_path()
            assert.are.equal("/home/user/gitrepo.git/worktrees/main.git", root_path)
        end)

        it("should handle being in the bare repo", function()
            utils._git_root_path = function()
                return "."
            end

            utils._get_pwd = function()
                return "/home/user/gitrepo.git"
            end

            local root_path = utils.get_git_root_path()
            assert.are.equal("/home/user/gitrepo.git", root_path)
        end)

        it("should fail when in a treeless repo", function()
            utils._git_root_path = function()
                return ".git"
            end

            assert.has_error(function()
                utils.get_git_root_path()
            end)
        end)

        it("should fail when not in a supported repo", function()
            utils._git_root_path = function()
                return nil
            end

            assert.has_error(function()
                utils.get_git_root_path()
            end)
        end)

        it("should handle when git root path is a subdirectory of the current directory", function()
            utils._git_root_path = function()
                return "./subdirectory/.git"
            end

            local root_path = utils.get_git_root_path()
            assert.are.equal("./subdirectory/.git", root_path)
        end)

        it("should handle when git root path is a relative path", function()
            utils._git_root_path = function()
                return "./relative/path/.git"
            end

            local root_path = utils.get_git_root_path()
            assert.are.equal("./relative/path/.git", root_path)
        end)
    end)
end)
