-- Test the local version of the module:
package.path = "../src/?.lua;" .. package.path
tplengine = require("template-text")


local function __check(ok, ret, expected)
    if not ok then
        local errmsg = string.format("Test failed. Template evaluation failed: %s", ret)
        error(errmsg)
    end
    if not (expected == ret) then
        local errmsg = string.format("Test failed: %q is not the same as %q", expected, ret)
        error(errmsg)
    end
end

local function test_basic(tpl, expected, env)
    local opts = {}
    local ok,ret = tplengine.template_eval(tpl, env, opts)
    __check(ok, ret, expected)
end

local function test_basic_xtend(tpl, expected, env)
    local opts = {xtendStyle=true}
    local ok,ret = tplengine.template_eval(tpl, env, opts)
    __check(ok, ret, expected)
end

local function test_syntax_error(tpl, env)
    local opts = {}
    local ok,ret = tplengine.parse(tpl, opts, env)
    if ok then
        local errmsg = string.format("Test failed. Syntax error expected but not raised")
        --print( table.concat(ret.code, "\n") )
        error(errmsg)
    end
end

local function test_eval_error(tpl, env, linenum)
    local opts = {}
    local ok,ret = tplengine.parse(tpl, opts, env)
    local erromsg
    if not ok then
        errmsg = string.format("Test failed. Unexpected syntax error: %s", ret)
        error(errmsg)
    end
    ok,ret = ret.evaluate()
    if ok then
        errmsg = string.format("Test failed. Evaluation error expected but not raised")
        error(errmsg)
    else
        --print(table.concat(ret, "\n"))
        if linenum ~= -1 then -- -1 signals not to try to find the line number
            local found = string.find(ret[2], "line " .. linenum)
            if found == nil then
                errmsg = string.format([[Test failed: unexpected line number (%d expected) for the template error.
    Returned error msg:
    %s]], linenum, table.concat(ret, "\n"))
                error(errmsg)
            end
        end
    end
end

test_basic("basic", "basic")
test_basic("$", "$")
test_basic("$()", "")
test_basic(" $()", " ")
test_basic("$() ", " ")
test_basic("$(33)", "33")
test_basic("$(3+3)", "6")
test_basic("$(false)", "false")
test_basic("$('str')", "str")
test_basic("$('str' .. 3)", "str3")
test_basic("$(var1)", "55", {var1=55})
test_basic("$(var1)", "0.123", {var1=0.123})
test_basic("$(var1)", "value", {var1="value"})
test_basic("Text $(v) interleaved", "Text EXTRA interleaved", {v="EXTRA"})
test_basic("Function $(f(6) + f(2))", "Function 40", {f=function(x) return x*x end})

test_basic_xtend("basic", "basic")
test_basic_xtend("$", "$")
test_basic_xtend("«»", "")
test_basic_xtend(" «»", " ")
test_basic_xtend("«» ", " ")
test_basic_xtend("«33»", "33")
test_basic_xtend("«3+3»", "6")
test_basic_xtend("«false»", "false")
test_basic_xtend("«'str'»", "str")
test_basic_xtend("«var1»", "value", {var1="value"})
test_basic_xtend("Text «v» interleaved", "Text EXTRA interleaved", {v="EXTRA"})
test_basic_xtend("Function «f(6) + f(2)»", "Function 40", {f=function(x) return x*x end})

test_basic("@", "")
test_basic(" @", "")
test_basic(" @ ", "")
test_basic("	@", "") -- these have TABs
test_basic("@	", "")

test_basic([[
@for i,v in ipairs({"wolf", "dog", "chicken"}) do
$(i) $(v)
@end
]], [[
1 wolf
2 dog
3 chicken]]
)

test_basic("${myTable}", [[line1
line2
line3]], {myTable={"line1","line2","line3"}})

--test_syntax_error("Should fail: $(()") -- does not fail at the moment because the %b() pattern does not match at all
test_syntax_error("Should fail: $(5*/8)")
test_syntax_error("Should fail: $(+)")
test_syntax_error("Should fail: $(.)")

test_eval_error("Shall fail: $(undefined)", {}, 1)

test_eval_error([[Shall fail:
$(not_there)"
this is line 3]], {}, 2)

test_eval_error("Shall fail: $(var) $(not_defined)", {var=33}, 1)
test_eval_error("Shall fail: $(f())", {}, 1)

test_eval_error([[
line 1
${undefined}
line 3
]], {}, 2)  -- error expected at line 2

-- At the moment, the engine does not include the line number in the main error
-- message, when the error is in a code line (starting with '@').
-- Therefore we cannot test the line number, and we pass -1
test_eval_error([[
@for i,v in ipairs(undefined) do
$(v)
@end]], {}, -1)


