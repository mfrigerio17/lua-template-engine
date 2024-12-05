-- Test the local version of the module:
package.path = "../src/?.lua;" .. package.path
local engine = require('template-text')
local test_common = require("common")

local dotest = function(case)
    return test_common.dotest(engine, case)
end

--- These tests exercise the options to control blank/empty lines resulting from
-- runtime evaluation, such as when a replacement field is found to be the empty
-- string in the evaluation environment.
--
-- We test replacement fields $() and table inclusion ${}


local env = {empty=""}

local tpl_with_empty = [[
Lorem ipsum dolor sit amet,
$(empty)$(empty)
consectetur adipiscing elit
]]

local tpl_with_blank = [[
Lorem ipsum dolor sit amet,
$(empty)  $(empty)
consectetur adipiscing elit
]] -- note the spaces between the empty variables

local expected_with_spaces = [[
Lorem ipsum dolor sit amet,
  
consectetur adipiscing elit
]] -- note the spaces in the midline

local expected_with_empty = [[
Lorem ipsum dolor sit amet,

consectetur adipiscing elit
]]

local expected_with_no_empty = [[
Lorem ipsum dolor sit amet,
consectetur adipiscing elit
]]

dotest( {
    id = "include-empty-line-by-default",
    desc = "by default, a line that evaluates to the empty line should be preserved",
    tpl = tpl_with_empty,
    expected = expected_with_empty,
    env = env,
    opts = {},
} )

dotest( {
    id = "include-empty-line",
    desc = "when using the dedicated option, a line that evaluates to the empty line should be preserved",
    tpl = tpl_with_empty,
    expected = expected_with_empty,
    env = env,
    opts = { preserve={empty=true} },
} )

dotest( {
    id = "exclude-empty-line",
    desc = "when using the dedicated option, a line that evaluates to the empty line should be dropped",
    tpl = tpl_with_empty,
    expected = expected_with_no_empty,
    env = env,
    opts = { preserve={empty=false} },
} )

dotest( {
    id = "include-blanks-by-default",
    desc = "by default, a line that evaluates to blanks only should be preserved",
    tpl = tpl_with_blank,
    expected = expected_with_spaces,
    env = env,
    opts = {},
} )

dotest( {
    id = "include-blanks",
    desc = "when using the dedicated option, a line that evaluates to blanks only should be preserved",
    tpl = tpl_with_blank,
    expected = expected_with_spaces,
    env = env,
    opts = { preserve={blank=true} },
} )

dotest( {
    id = "exclude-blanks",
    desc = "with the right options, trailing spaces should be dropped but the empty line preserved",
    tpl = tpl_with_blank,
    expected = expected_with_empty,
    env = env,
    opts = { preserve={blank=false, empty=true} },
} )

dotest( {
    id = "exclude-blanks-and-empty",
    desc = "with the right options, a line that evaluates only to blanks is dropped altogether",
    tpl = tpl_with_blank,
    expected = expected_with_no_empty,
    env = env,
    opts = { preserve={blank=false, empty=false} },
} )

-- ----------------------------------- --
-- Now tests involving table inclusion --
-- ----------------------------------- --
env.empty_table={}

local tpl_with_empty_table = [[
Lorem ipsum dolor sit amet,
  ${empty_table}
consectetur adipiscing elit
]]

dotest( {
    id = "include-leading-spaces-by-default",
    desc = "by default, an included empty table with leading spaces results in the spaces only",
    tpl = tpl_with_empty_table,
    expected = expected_with_spaces,
    env = env,
    opts = {},
} )

dotest( {
    id = "include-leading-spaces",
    desc = "with explicit option, an included empty table with leading spaces results in the spaces only",
    tpl = tpl_with_empty_table,
    expected = expected_with_spaces,
    env = env,
    opts = { preserve={blank=true} },
} )

dotest( {
    id = "exclude-leading-spaces",
    desc = "an included empty table with leading spaces results in an empty line, when options say so",
    tpl = tpl_with_empty_table,
    expected = expected_with_empty,
    env = env,
    opts = { preserve={blank=false, empty=true} },
    -- opts: do not preserve blanks in lines which evaluate to blanks only, but
    --   preserve the line itself (ie only a newline)
} )

dotest( {
    id = "exclude-blank-line",
    desc = "an included empty table with leading spaces is completely dropped, when options say so",
    tpl = tpl_with_empty_table,
    expected = expected_with_no_empty,
    env = env,
    opts = { preserve={blank=false, empty=false} },
} )


--
-- Tests with a non-empty table that contains blank/empty lines
--

local includeMe = {"table line 1", "    ", "table line 3", "", "table line 5" }
local tpl = [[
First line
${includeMe}
Last line
]]

local expected_preserve_all = [[
First line
table line 1
    
table line 3

table line 5
Last line
]] -- both spaces(blanks) and newlines are there

local expected_preserve_empty = [[
First line
table line 1

table line 3

table line 5
Last line
]] -- only newlines; blanks in line 2 of the table are stripped

local expected_preserve_none = [[
First line
table line 1
table line 3
table line 5
Last line
]] -- blanks and newlines are dropped

env.includeMe = includeMe

dotest( {
    id = "preserve-table-lines",
    desc = "the lines in a table are preserved, including blank and empty lines",
    tpl = tpl,
    expected = expected_preserve_all,
    env = env,
    opts = { preserve={blank=true, empty=true} },
} )

dotest( {
    id = "preserve-table-newlines",
    desc = "empty lines in a table are preserved, but blank characters alone are dropped",
    tpl = tpl,
    expected = expected_preserve_empty,
    env = env,
    opts = { preserve={blank=false, empty=true} },
} )

dotest( {
    id = "drop-table-empty-lines",
    desc = "both space-only and empty lines in a table are dropped",
    tpl = tpl,
    expected = expected_preserve_none,
    env = env,
    opts = { preserve={blank=false, empty=false} },
} )


--
-- One more test with a for loop and replacement fields
--
env.values = {"monkey", "bear", "", "ladybug", "", "salmon"}

tpl = [[
@for i,v in ipairs(values) do
    $(v)
@end
]]

local expected = [[
    monkey
    bear

    ladybug

    salmon
]] -- note the leading spaces due to the indentation of '$(v)' in the template,
-- are dropped for the empty elements of the list

dotest( {
    id = "drop-leading-spaces-in-forloop",
    desc = "leading spaces in otherwise empty lines generated by a for loop are stripped",
    tpl = tpl,
    expected = expected,
    env = env,
    opts = { preserve={blank=false, empty=true} },
} )
