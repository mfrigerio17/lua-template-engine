-- Test the local version of the module:
package.path = "../src/?.lua;" .. package.path
local engine = require('template-text')

local noblanks = function(line) return not line:match("^%s+$") end

local dotest = function(case)
    local iterator = engine.lineDecorator(case.original_iter or ipairs, case.opts)
    for k, line in iterator(case.src) do
        assert( case.expected[k] == line,
            string.format("case '%s' failed at key '%s': expected '%s'  got '%s'",
                case.id, k, case.expected[k], line) )
    end
end


dotest({
    id = "simple",
    src = {"AAA", "BBB"},
    expected = {"AAA", "BBB"},
    opts = {},
})

dotest({
    id = "simple-prefix",
    src = {"AAA", "", "BBB"},
    expected = {"___AAA", "___", "___BBB"},
    opts = {prefix="___"},
})

dotest({
    id = "simple-suffix",
    src = {"AAA", "", "BBB"},
    expected = {"AAA___", "___", "BBB___"},
    opts = {suffix="___"},
})

dotest({
    id = "filter-blanks",
    src = {"AAA", "  ", "BBB", "    ", " ", "CC"},
    expected = {"AAA___", "BBB___", "CC___"},
    opts = {suffix="___", filter=noblanks},
})

dotest({
    id = "filter-blanks-only",
    src = {" ", "  ", " ", "    ", " "},
    expected = {},
    opts = {suffix="***", filter=noblanks},
})

dotest({
    id = "composability",
    original_iter = engine.lineDecorator(ipairs, {prefix='***'}),
    src = {"A", "B", " ", ""},
    expected = {"***B", "*** ", "***"},
    opts = {filter=function(s) return not s:match('*A') end},
})


dotest({
    id = "original-iterator-factory-is-a-closure-on-data",
    src = nil, -- this could be anything, it will be ignored anyway
    original_iter = function() return ipairs({"AAA", "BBB"}) end,
    expected = {"AAA","BBB"},
})


dotest({
    id = "original-iterator-factory-is-a-closure-on-data-2",
    src = nil, -- this could be anything, it will be ignored anyway
    original_iter = function() return ipairs({"AAA", "BBB"}) end,
    expected = {"AAA-->","BBB-->"},
    opts = {suffix="-->"},
})
