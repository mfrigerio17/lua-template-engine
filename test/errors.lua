--- Test cases where a loading/evaluation error is expected.
--
-- These tests verify malformed templates are reported as such.
-- No specific assertion is performed on the reported error message, as that is
-- not structured and also mutable data. Print the message to verify manually
-- that it is informative.

-- Test the local version of the module, not the installed one:
package.path = "../src/?.lua;" .. package.path

local engine      = require("template-text")
local test_common = require("common")
local ret1, ret2, ret3

-- -------------------------------------------------------------------------- --
local case = {
    id = "wrong_syntax_1",
    desc = "basic syntax error",
    tpl =
[[
This is a syntax error: $( 5 -* 1)
]],
    env = {},
}

ret1,ret2 = test_common.dotest_expect_load_error(engine, case)
-- print the error message to double check it is meaningful
-- print(table.concat(ret2, "\n"))



-- -------------------------------------------------------------------------- --
-- this one checks on error reporting in the case of the template inclusion,
-- with multiple levels of inclusion.
case = {
    id = "wrong_syntax_nested",
    desc = "syntax error in a nested, included template",
    tpl = [[
$<nested>
]],
    env = {},
    included = {
        nested = [[
some text
$<buggy>
]],
        buggy = [[
some text before the error
$("str)
]]
    },
}

ret1, ret2 = test_common.dotest_expect_load_error(engine, case)
-- print the error message to double check it is meaningful
-- print(table.concat(ret2, "\n"))


-- -------------------------------------------------------------------------- --
case = {
    id = "missing_include",
    desc = "referencing a template that is not given should result in a loading error",
    tpl = [[
First line
  $<missing>
Last line
]],
    env = {},
    included = {},
}

ret1, ret2 = test_common.dotest_expect_load_error(engine, case)
-- print the error message to double check it is meaningful
-- print(table.concat(ret2, "\n"))


-- -------------------------------------------------------------------------- --
-- A depth-2 nesting, but the second template is undefined
case = {
    id = "missing_nested_include",
    desc = "an included template that includes another one, which is missing, should generate and appropriate error",
    tpl = [[
First line
$<included1>
Last line
]],
    env = {},
    included = { included1 =[[
...
$<included2>
...
]],
    }, -- note, there is no 'included2' template source
}
ret1, ret2 = test_common.dotest_expect_load_error(engine, case)
-- print the error message to double check it is meaningful
-- print(table.concat(ret2, "\n"))




-- Check error reporting for an evaluation-time error originating in a runtime
-- error in a function defined outside of the template.

local function buggy(arg)
    return arg .. undefined
end

local function to_deepen_the_stacktrace(arg)
    local arg2 = buggy(arg)
    return arg2
end

case = {
    id = "runtime_err_external",
    desc = "runtime error in a function defined outside of the template",
    tpl =
[[
@local g = function(arg) local ret=f(arg); return ret end
some text here and there
Calling g("arg"): $(g("arg"))
]],
    env = {f= to_deepen_the_stacktrace},
}

ret1, ret2 = test_common.dotest_expect_eval_error(engine, case)
-- print the error message to double check it is meaningful
-- print(table.concat(ret2, "\n"))





