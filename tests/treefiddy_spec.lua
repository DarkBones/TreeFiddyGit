local assert = require("luassert")

describe("TreeFiddyGit", function()
    it("should load the plugin", function()
        local ok, plugin = pcall(require, "TreeFiddyGit")
        assert.is_true(ok)
        assert.is_not_nil(plugin)
    end)
end)
