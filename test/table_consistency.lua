-- Test the local version of the module:
package.path = "../src/?.lua;" .. package.path
local engine = require('template-text')
local test_common = require("common")

-------------------------------------------------------------------------------
-- Tests about the consistency of replacement fields and table inclusion ------
--
-- We want to ensure that including a table is equivalent to iterate over the
-- table items and expanding each item.


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
$(indent)${myTable}
BBB
]]--note that ${myTable} does not need to be quoted

local meta_template_with_for = [[
AAA
\@for _,line in ipairs(myTable) do
$(indent)\$(line)
\@end
BBB
]]

local testing_tables = {
    {"line 1", "line 2", "line 3"},
    {"line 1", "", "    ", "line 4"},
    {},
}


local tests_over_opts_combinations = function(tpl1, tpl2, env)
    local opts = { preserve={blank=false, empty=true} }
    local ret1, ret2
    for _,testopts in ipairs( {{true,true},{true,false},{false,true},{false,false}} ) do
        opts.preserve.blank = testopts[1]
        opts.preserve.empty = testopts[2]

        ret1 = tpleval(tpl1, env, opts)
        ret2 = tpleval(tpl2, env, opts)

        if not (ret1==ret2) then
            print(string.format("with preserve blanks: %s  preserve empty: %s", testopts[1], testopts[2]))
            print(ret1)
            print(ret2)
            error("Consistency test failed", 2)
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



perform_tests( {indent=""} )
perform_tests( {indent="  "} )
