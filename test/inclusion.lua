-- Test the local version of the module:
package.path = "../src/?.lua;" .. package.path
local engine = require('template-text')
local test_common = require('common')


local master = [[
Lorem ipsum dolor sit amet,
$<lines23>

$<lines45>
]]

local lines23 = [[
consectetur adipiscing elit,
sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.]]
-- note that I must close the ]] right after the text if I dont want an extra
-- newline to appear when rendering

local lines45 = [[
Ut enim ad minim veniam,
quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.]]

local expected = [[
Lorem ipsum dolor sit amet,
consectetur adipiscing elit,
sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.

Ut enim ad minim veniam,
quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
]]

local case = {
    id = "inclusion_test_1",
    desc = "simple test demonstrating template composition by inclusion",
    tpl = master,
    env = {},
    opts = {},
    included = {["lines23"]=lines23, ["lines45"]=lines45},
    expected = expected,
}

test_common.dotest(engine, case)



local tpl_animals = [[
@ for i, a in ipairs(animals) do
Animal $(i) is $(a)
@ end]]

local tpl_habitats = [[
$<animals>
Habitats:
prairie, marsh, forest, desert, steppe, mesa]]

master = [[
Here are some animals and habitats:
    $<nature>

The list of animals again:
$<animals>
]]

local animals = {"crocodile", "chicken", "bear"}

expected = [[
Here are some animals and habitats:
    Animal 1 is crocodile
    Animal 2 is chicken
    Animal 3 is bear
    Habitats:
    prairie, marsh, forest, desert, steppe, mesa

The list of animals again:
Animal 1 is crocodile
Animal 2 is chicken
Animal 3 is bear
]]

case = {
    id = "inclusion_test_2",
    desc = "nested inclusion, with expressions in the included templates",
    tpl = master,
    env = {animals=animals},
    opts = {},
    included = { animals=tpl_animals, nature=tpl_habitats },
    expected = expected,
}

test_common.dotest(engine, case)


-- -------------------------------------------------------------------------- --

master = [[
Only a single template can be included per line. Thus, this one

$<looks_like> $<two_of_them>

will actually look for the template named "looks_like> $<two_of_them"
]]

case = {
    id = "inclusion_test_3",
    desc = "the pattern match for the included template is greedy",
    tpl  = master,
    env  = {},
    opts = {},
    included = {["looks_like> $<two_of_them"] = [[
content of the
included template]]},
    expected = [[
Only a single template can be included per line. Thus, this one

content of the
included template

will actually look for the template named "looks_like> $<two_of_them"
]]
}

test_common.dotest(engine, case)

