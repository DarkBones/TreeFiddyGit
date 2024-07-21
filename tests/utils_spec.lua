---@diagnostic disable: duplicate-set-field

local async = require("plenary.async")
local assert = require("luassert")

describe("utils", function()
    local utils = require("TreeFiddyGit.utils")

    describe("deep_merge", function()
        it("merges simple key-value pairs", function()
            local base_table = { a = "banana", b = "apple" }
            local new_table = { b = "orange", c = "grape" }
            local result = utils.deep_merge(base_table, new_table)
            assert.are.same(result, { a = "banana", b = "orange", c = "grape" })
        end)

        it("merges nested tables", function()
            local base_table = { a = "banana", b = { x = "cat", y = "dog" } }
            local new_table = { b = { y = "fox", z = "wolf" } }
            local result = utils.deep_merge(base_table, new_table)
            assert.are.same(result, { a = "banana", b = { x = "cat", y = "fox", z = "wolf" } })
        end)

        it("overwrites non-table values with table values", function()
            local base_table = { a = "banana", b = "apple" }
            local new_table = { b = { x = "monkey" } }
            local result = utils.deep_merge(base_table, new_table)
            assert.are.same(result, { a = "banana", b = { x = "monkey" } })
        end)

        it("overwrites table values with non-table values", function()
            local base_table = { a = "banana", b = { x = "cat" } }
            local new_table = { b = "orange" }
            local result = utils.deep_merge(base_table, new_table)
            assert.are.same(result, { a = "banana", b = "orange" })
        end)

        it("handles empty base table", function()
            local base_table = {}
            local new_table = { a = "banana", b = "apple" }
            local result = utils.deep_merge(base_table, new_table)
            assert.are.same(result, { a = "banana", b = "apple" })
        end)

        it("handles empty new table", function()
            local base_table = { a = "banana", b = "apple" }
            local new_table = {}
            local result = utils.deep_merge(base_table, new_table)
            assert.are.same(result, { a = "banana", b = "apple" })
        end)

        it("handles deeply nested tables", function()
            local base_table = { a = { b = { c = { d = "unicorn" } } } }
            local new_table = { a = { b = { c = { e = "dragon" } } } }
            local result = utils.deep_merge(base_table, new_table)
            assert.are.same(result, { a = { b = { c = { d = "unicorn", e = "dragon" } } } })
        end)

        it("handles identical nested tables", function()
            local base_table = { a = { b = { c = "unicorn" } } }
            local new_table = { a = { b = { c = "dragon" } } }
            local result = utils.deep_merge(base_table, new_table)
            assert.are.same(result, { a = { b = { c = "dragon" } } })
        end)

        it("merges tables with nil values by ignoring the new nil", function()
            local base_table = { a = "banana", b = "apple" }
            local new_table = { b = nil, c = "grape" }
            local result = utils.deep_merge(base_table, new_table)
            assert.are.same(result, { a = "banana", b = "apple", c = "grape" })
        end)
    end)

    describe("_is_absolute_path", function()
        it("returns false if relative path", function()
            assert.is_false(utils._is_absolute_path("./relative/path"))
            assert.is_false(utils._is_absolute_path("relative/path"))
            assert.is_false(utils._is_absolute_path("relative_path"))
            assert.is_false(utils._is_absolute_path("relative\\path"))
            assert.is_false(utils._is_absolute_path("XYZ:/\\absolute"))
            assert.is_false(utils._is_absolute_path(""))
            assert.is_false(utils._is_absolute_path("."))
            assert.is_false(utils._is_absolute_path(".."))
            assert.is_false(utils._is_absolute_path("\\absolute\\path"))
        end)

        it("returns true if absolute path", function()
            assert.is_true(utils._is_absolute_path("/absolute/path"))
            assert.is_true(utils._is_absolute_path("/absolute_path"))
            assert.is_true(utils._is_absolute_path("C:/\\absolute\\path"))
            assert.is_true(utils._is_absolute_path("X:/\\absolute"))
            assert.is_true(utils._is_absolute_path("//network/share"))
            assert.is_true(utils._is_absolute_path("C:/Program Files"))
        end)

        it("handles mixed and edge cases", function()
            assert.is_false(utils._is_absolute_path("relative/path/with:/colon"))
            assert.is_true(utils._is_absolute_path("/absolute/path/with:/colon"))
            assert.is_true(utils._is_absolute_path("C:\\absolute\\path\\with spaces"))
            assert.is_true(utils._is_absolute_path("C:\\absolute\\path\\with.dots"))
            assert.is_false(utils._is_absolute_path("relative/path/with\\backslash"))
            assert.is_true(
                utils._is_absolute_path("Z:/a/very/long/path/that/keeps/going/and/going/and/going/and/going")
            )
        end)
    end)

    describe("_make_absolute", function()
        it("returns the same path if the given path is already absolute unix", function()
            local path = "/path/that/is/already/absolute"
            local root = "/root/path"

            local abs_path = utils._make_absolute(root, path)
            assert.are.equal(path, abs_path)
        end)

        it("returns the same path if the given path is already absolute windows", function()
            local path = "C:\\absolute\\windows\\path"
            local root = "X:\\root\\path"

            local abs_path = utils._make_absolute(root, path)
            assert.are.equal(path, abs_path)
        end)

        it("joins the root and path if path is relative unix", function()
            local path = "./relative/path"
            local root = "/root/path"

            local abs_path = utils._make_absolute(root, path)
            assert.are.equal("/root/path/relative/path", abs_path)

            path = "other/relative/path"
            abs_path = utils._make_absolute(root, path)
            assert.are.equal("/root/path/other/relative/path", abs_path)

            path = "relative/path/with\\backslash/character"
            abs_path = utils._make_absolute(root, path)
            assert.are.equal("/root/path/relative/path/with\\backslash/character", abs_path)
        end)

        it("joins the root and path if path is relative windows", function()
            local path = ".\\relative\\path"
            local root = "C:\\root\\path"

            local abs_path = utils._make_absolute(root, path)
            assert.are.equal("C:\\root\\path\\relative\\path", abs_path)

            path = "other\\relative\\path"
            abs_path = utils._make_absolute(root, path)
            assert.are.equal("C:\\root\\path\\other\\relative\\path", abs_path)

            path = "relative\\path\\with/slash\\character"
            abs_path = utils._make_absolute(root, path)
            assert.are.equal("C:\\root\\path\\relative\\path\\with/slash\\character", abs_path)
        end)

        it("handles empty path correctly", function()
            local path = ""
            local root = "/root/path"

            local abs_path = utils._make_absolute(root, path)
            assert.are.equal("/root/path/", abs_path)
        end)

        it("handles dot path correctly", function()
            local path = "."
            local root = "/root/path"

            local abs_path = utils._make_absolute(root, path)
            assert.are.equal("/root/path/.", abs_path)
        end)

        it("handles double dot path correctly", function()
            local path = ".."
            local root = "/root/path"

            local abs_path = utils._make_absolute(root, path)
            assert.are.equal("/root/path/..", abs_path)
        end)

        it("joins the root and path if root ends with a separator", function()
            local path = "relative/path"
            local root = "/root/path/"

            local abs_path = utils._make_absolute(root, path)
            assert.are.equal("/root/path/relative/path", abs_path)
        end)

        it("handles mixed slashes in path correctly for unix", function()
            local path = "relative\\path/with/mixed/slashes"
            local root = "/root/path"

            local abs_path = utils._make_absolute(root, path)
            assert.are.equal("/root/path/relative\\path/with/mixed/slashes", abs_path)
        end)

        it("handles mixed slashes in path correctly for windows", function()
            local path = "relative/path\\with\\mixed/slashes"
            local root = "C:\\root\\path"

            local abs_path = utils._make_absolute(root, path)
            assert.are.equal("C:\\root\\path\\relative/path\\with\\mixed/slashes", abs_path)
        end)
    end)

    describe("get_absolute_wt_path", function()
        local jobs = require("TreeFiddyGit.jobs")

        local original_get_git_worktree_reference = jobs._get_git_worktree_reference
        local original_is_in_bare_repo = jobs._in_bare_repo
        local original_get_pwd = jobs._get_pwd

        after_each(function()
            jobs._get_git_worktree_reference = original_get_git_worktree_reference
            jobs._in_bare_repo = original_is_in_bare_repo
            jobs._get_pwd = original_get_pwd
        end)

        async.tests.it("returns the same path if already absolute", function()
            jobs._get_git_worktree_reference = vim.schedule_wrap(function(callback)
                callback({ "/home/user/gitrepo.git/worktrees/main" }, nil)
            end)

            local path = "/already/absolute/path/to/git_repo.git"
            local result, err = async.wrap(utils.get_absolute_wt_path, 2)(path)

            assert.is_nil(err)
            assert.are.equal(result, path)
        end)

        async.tests.it("returns the absolute path if a relative path is given", function()
            jobs._get_git_worktree_reference = vim.schedule_wrap(function(callback)
                callback({ "/home/user/gitrepo.git/worktrees/main" }, nil)
            end)

            local path = "./relative_path"
            local result, err = async.wrap(utils.get_absolute_wt_path, 2)(path)

            assert.is_nil(err)
            assert.are.equal(result, "/home/user/gitrepo.git/relative_path")
        end)

        async.tests.it("handles relative path without dot correctly", function()
            jobs._get_git_worktree_reference = vim.schedule_wrap(function(callback)
                callback({ "/home/user/gitrepo.git/worktrees/main" }, nil)
            end)

            local path = "relative/path"
            local result, err = async.wrap(utils.get_absolute_wt_path, 2)(path)

            assert.is_nil(err)
            assert.are.equal(result, "/home/user/gitrepo.git/relative/path")
        end)
    end)

    describe("update_worktree_buffer_path", function()
        it("updates the buffer path with the new worktree path", function()
            local old_git_path = "/home/user/gitrepo.git/main"
            local new_git_path = "/home/user/gitrepo.git/new"
            local buf_path = "/home/user/gitrepo.git/main/file.txt"

            local result = utils.update_worktree_buffer_path(old_git_path, new_git_path, buf_path)
            assert.are.equal("/home/user/gitrepo.git/new/file.txt", result)
        end)

        it("handles paths from bare correctly", function()
            local old_git_path = "/home/user/gitrepo.git"
            local new_git_path = "/home/user/gitrepo.git/new"
            local buf_path = "/home/user/gitrepo.git/file.txt"

            local result = utils.update_worktree_buffer_path(old_git_path, new_git_path, buf_path)
            assert.are.equal("/home/user/gitrepo.git/new/file.txt", result)
        end)

        it("does not update paths not in the old path", function()
            local old_git_path = "/home/user/gitrepo.git/main"
            local new_git_path = "/home/user/gitrepo.git/new"
            local buf_path = "/home/user/gitrepo.git/other-branch/file.txt"

            local result = utils.update_worktree_buffer_path(old_git_path, new_git_path, buf_path)
            assert.are.equal("/home/user/gitrepo.git/other-branch/file.txt", result)
        end)
    end)
end)
