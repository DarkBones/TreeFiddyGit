---@diagnostic disable: duplicate-set-field

local async = require("plenary.async")
local assert = require("luassert")

describe("parsers", function()
    local parsers = require("TreeFiddyGit.parsers")
    local jobs = require("TreeFiddyGit.jobs")
    local utils = require("TreeFiddyGit.utils")

    describe("parse_worktrees", function()
        local original_get_git_root_path = jobs.get_git_root_path
        local original_make_relative = utils.make_relative

        before_each(function()
            jobs.get_git_root_path = function(callback)
                callback("/home/user/gitrepo.git", nil)
            end
            utils.make_relative = function(path, root)
                return path:gsub(root .. "/", "")
            end
        end)

        after_each(function()
            jobs.get_git_root_path = original_get_git_root_path
            utils.make_relative = original_make_relative
        end)

        async.tests.it("parses worktrees into neat columns", function()
            local worktrees = {
                "/home/user/gitrepo.git/main 1234567 [main]",
                "/home/user/gitrepo.git/dev 89abcde [dev]",
            }

            local expected = {
                "main ./main 1234567",
                "dev  ./dev  89abcde",
            }

            local result, err = async.util.block_on(function()
                return async.wrap(parsers.parse_worktrees, 2)(worktrees)
            end)

            assert.is_nil(err)
            assert.are.same(expected, result)
        end)

        async.tests.it("parses long worktrees into neat columns", function()
            local worktrees = {
                "/home/user/gitrepo.git/main 1234567 [main]",
                "/home/user/gitrepo.git/dev 89abcde [dev]",
                "/home/user/gitrepo.git/worktree-with-long-name h4a9cde [worktree-with-long-name]",
            }

            local expected = {
                "main                    ./main                    1234567",
                "dev                     ./dev                     89abcde",
                "worktree-with-long-name ./worktree-with-long-name h4a9cde",
            }

            local result, err = async.util.block_on(function()
                return async.wrap(parsers.parse_worktrees, 2)(worktrees)
            end)

            assert.is_nil(err)
            assert.are.same(expected, result)
        end)

        async.tests.it("handles errors from get_git_root_path", function()
            jobs.get_git_root_path = function(callback)
                callback(nil, "error")
            end

            local worktrees = {
                "/home/user/gitrepo.git/worktrees/main 1234567 [main]",
            }

            local result, err = async.util.block_on(function()
                return async.wrap(parsers.parse_worktrees, 2)(worktrees)
            end)

            assert.is_nil(result)
            assert.are.equal("error", err)
        end)
    end)

    describe("parse_branch_name", function()
        it("removes leading and trailing whitespace", function()
            local branch_name = "  feature/new-feature  "
            local expected = "feature/new-feature"
            local result = parsers.parse_branch_name(branch_name)
            assert.are.equal(expected, result)
        end)

        it("replaces invalid characters with hyphens", function()
            local branch_name = "feature@new!feature#1"
            local expected = "feature-new-feature-1"
            local result = parsers.parse_branch_name(branch_name)
            assert.are.equal(expected, result)
        end)

        it("replaces spaces with hyphens", function()
            local branch_name = "feature new feature 1"
            local expected = "feature-new-feature-1"
            local result = parsers.parse_branch_name(branch_name)
            assert.are.equal(expected, result)
        end)

        it("replaces spaces with hyphens and remove trailing and leading spaces", function()
            local branch_name = " feature new feature 1    "
            local expected = "feature-new-feature-1"
            local result = parsers.parse_branch_name(branch_name)
            assert.are.equal(expected, result)
        end)

        it("handles empty branch names", function()
            local branch_name = ""
            local expected = ""
            local result = parsers.parse_branch_name(branch_name)
            assert.are.equal(expected, result)
        end)

        it("retains valid characters", function()
            local branch_name = "feature/new-feature_123"
            local expected = "feature/new-feature_123"
            local result = parsers.parse_branch_name(branch_name)
            assert.are.equal(expected, result)
        end)
    end)

    describe("parse_path", function()
        it("removes leading and trailing whitespace", function()
            local path = "  /home/user/project  "
            local expected = "home/user/project"
            local result = parsers.parse_path(path)
            assert.are.equal(expected, result)
        end)

        it("replaces backslashes with forward slashes", function()
            local path = "C:\\Users\\User\\project"
            local expected = "C-/Users/User/project"
            local result = parsers.parse_path(path)
            assert.are.equal(expected, result)
        end)

        it("replaces non-alphanumeric characters with hyphens", function()
            local path = "/home/user:project"
            local expected = "home/user-project"
            local result = parsers.parse_path(path)
            assert.are.equal(expected, result)
        end)

        it("replaces spaces with hyphens", function()
            local path = "/home/user/my project with spaces"
            local expected = "home/user/my-project-with-spaces"
            local result = parsers.parse_path(path)
            assert.are.equal(expected, result)
        end)

        it("resolves '.' segments", function()
            local path = "/home/user/./project"
            local expected = "home/user/-/project"
            local result = parsers.parse_path(path)
            assert.are.equal(expected, result)
        end)

        it("resolves '..' segments", function()
            local path = "/home/user/../project"
            local expected = "home/user/--/project"
            local result = parsers.parse_path(path)
            assert.are.equal(expected, result)
        end)

        it("handles complex paths", function()
            local path = "/home/user/./../user2/project/../project2"
            local expected = "home/user/-/--/user2/project/--/project2"
            local result = parsers.parse_path(path)
            assert.are.equal(expected, result)
        end)

        it("handles paths with multiple slashes", function()
            local path = "/home//user///project"
            local expected = "home/user/project"
            local result = parsers.parse_path(path)
            assert.are.equal(expected, result)
        end)

        it("handles empty paths", function()
            local path = ""
            local expected = ""
            local result = parsers.parse_path(path)
            assert.are.equal(expected, result)
        end)

        it("handles root paths", function()
            local path = "/"
            local expected = ""
            local result = parsers.parse_path(path)
            assert.are.equal(expected, result)
        end)
    end)
end)
