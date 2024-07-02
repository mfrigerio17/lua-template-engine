local engine = require('template-text')

local tpl = [[
Hi! This is a text template!
It can reference any symbol which is defined in the environment (i.e. a table)
given to the evaluation function:

Hello $(name) for $(many(5)) times!

Actual Lua code can be used in the template, starting the line with a '@':
@ for k,v in pairs( aTable ) do
key: $(k)    value: $(v)
@ end
]]

local dummyF = function(i) return i*3 end
local dummyT = {"bear", "wolf", "shark", "monkey"}

local ok, parsed = engine.tload(tpl, {},
  { name   = "Marco",
    many   = dummyF,
    aTable = dummyT}
)
if not ok then
    error(parsed) -- in this case 'parsed' is an error message
else
    local text
    ok, text = parsed.evaluate()
    if not ok then
        error(table.concat(text, "\n"))
    else
        print(text)
    end
end
