-- Test the local version of the module:
package.path = "../src/?.lua;" .. package.path
local engine = require('template-text')
local test_common = require("common")

-------------------------------------------------------------------------------
-- Tests about the consistency of replacement fields and table inclusion ------
--
-- I want to ensure that including a table is equivalent to iterate over the
-- table items and expanding each item. That is,
--
--   <indent>${aTable}
--
-- must be equivalent to
--
--   @for _,line in ipairs(aTable) do
--   <indent>$(line)
--   @end
--
-- for any <indent>. I test this property quite literally, with two
-- meta-templates like the pseudo-ones above, which I use to generate
-- the same two templates for different values of <indent>.

local tpleval = function(tpl, env, opts)
    local ok, ret = engine.template_eval(tpl, env, opts)
    if not ok then
        print(ret)
        error("unexpected failure in template eval", 3)
    end
    return ret
end


local meta_template_with_table_inclusion = [[
AAA
$(literal_indentation)${myTable}
BBB
]]--note that ${myTable} does not need to be quoted (is not alone on the line thus it does not expand)

local meta_template_with_for = [[
AAA
\@for _,line in ipairs(myTable) do
$(literal_indentation)\$(line)
\@end
BBB
]]

local testing_tables = {
    {"line 1", "line 2", "line 3"},
    {"line 1", "", "  ", "line 4"},
    {},
    {"","","line 3"},
}


local tests_over_opts_combinations = function(tpl_table, tpl_forloop, env)
    local opts = { preserve={blank=false, empty=true} }
    local ret1, ret2
    for _,testopts in ipairs( {{true,true},{true,false},{false,true},{false,false}} ) do
    for eval_indent = 0,3,3 do -- indent 0 or 3
        opts.preserve.blank = testopts[1]
        opts.preserve.empty = testopts[2]
        opts.indent = eval_indent

        ret1 = tpleval(tpl_table, env, opts)
        ret2 = tpleval(tpl_forloop, env, opts)

        if not (ret1==ret2) then
            print(string.format("opt indent: %d  preserve blanks: %s  preserve empty: %s", eval_indent, testopts[1], testopts[2]))
            print("Table inclusion:")
            print( (ret1:gsub(" ", "·")) )
            print("")
            print("For loop:")
            print( (ret2:gsub(" ", "·")) )
            error("Consistency test failed", 2)
        end
    end
    end
end

local perform_tests = function( metaenv )
    -- first, generate the testing templates from the meta-templates
    local template_with_table_inclusion =
        tpleval(meta_template_with_table_inclusion, metaenv)
    local template_with_for =
        tpleval(meta_template_with_for, metaenv)

    local env = {}
    for i, myTable in ipairs(testing_tables) do
        env.myTable = myTable
        tests_over_opts_combinations(template_with_table_inclusion, template_with_for, env)
    end
end



perform_tests( {literal_indentation=""} )
perform_tests( {literal_indentation="  "} )
