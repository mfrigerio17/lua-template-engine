-- Test the local version of the module:
package.path = "../src/?.lua;" .. package.path
local engine = require('template-text')
local test_common = require("common")

local dotest = function(case)
    return test_common.dotest(engine, case)
end


local test1 = {
    id = "test1",
    tpl =
[[
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
$(lorem_ipsum_2).
]],
    expected =
[[
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
]],
    env = {
        lorem_ipsum_2 = "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat",
    },
    opts = {},
}


local test2 = {
    id = "test2",
    desc = "simple test of misc features",
    tpl =
[[
Lorem ipsum dolor sit amet
Lorem $(ipsum) dolor $(sit) amet

@for i,word in ipairs(words) do
$(word)
@end

    $(phrase)
$(table.concat(words, " "))
]],
    expected =
[[
Lorem ipsum dolor sit amet
Lorem ipsum dolor sit amet

Lorem
ipsum
dolor
sit
amet

    Lorem ipsum dolor sit amet
Lorem ipsum dolor sit amet
]],
    env = {
        ipsum = "ipsum",
        sit = "sit",
        words = {"Lorem", "ipsum", "dolor", "sit", "amet"},
        phrase = "Lorem ipsum dolor sit amet",
    },
    opts = {}
}


local test3 = {
    id = "test3",
    desc = "test table expansion, preserving indentation",
    tpl =
[[
${lines}
    ${lines}
${empty}
Only when alone in the line: ${lines}
${lines}: Only when alone in the line
]],
    expected =
[[
Lorem ipsum dolor sit amet
consectetur adipiscing elit
    Lorem ipsum dolor sit amet
    consectetur adipiscing elit
Only when alone in the line: ${lines}
${lines}: Only when alone in the line
]],
    env = {
        lines = {"Lorem ipsum dolor sit amet", "consectetur adipiscing elit"},
        empty = {},
    },
    opts = {},
}


local test4 = {
    id = "test4",
    desc = "test Xtend-style delimiters",
    tpl =
[[
$(var1) «var1»

    «var2» «f(5)»  .
]],
    expected =
[[
$(var1) value1

    value2 25  .
]],
    env = {
        var1="value1", var2="value2",
        f = function(x) return x*x end,
    },
    opts = {xtendStyle=true},
}




dotest(test1)
dotest(test2)
dotest(test3)
dotest(test4)
