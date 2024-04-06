-- Test the local version of the module:
package.path = "../src/?.lua;" .. package.path
local engine = require('template-text')
local common = require("common")

-- A few test cases where multiple templates are bound to the same
-- environment, to "verify" that there is no interference


local tpl1 = [[
line 1:
line 2: $(field)]]

local tpl2 = [[

text
    ${tpl1}
text
$(field)
]]

local expected = [[

text
    line 1:
    line 2: value
text
value
]]

local env = { field="value" }

local loaded_tpl1 = common.do_load_fail_on_error(engine, {tpl=tpl1, env=env})

env.tpl1 = common.do_eval_fail_on_error(loaded_tpl1, {returnTable=true})

common.dotest(engine, {tpl=tpl2, env=env, expected=expected, id="shared_env_subsequent_eval"})


-- The next test exercises nested evaluation, a specific case in which
-- evaluation of the outer template requires evaluation of another one,
-- in this case bound to the same environment.
-- Note the difference with the previous case, where the two evaluations
-- happen in sequence

tpl2 = [[

text
    ${tpl1()}
text
$(field)
]]

-- the trick to defer the evaluation of the first template _during_
--  evaluation of the second, is to use a function that performs the
--  evaluation and returns the table, as opposed to the table itself
env.tpl1 = function() return common.do_loadeval_fail_on_error(engine, {tpl=tpl1, env=env, opts={returnTable=true}}) end

common.dotest(engine, {tpl=tpl2, env=env, expected=expected})

