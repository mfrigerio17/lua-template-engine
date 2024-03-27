local engine = require('template-text')

local test = function(env, opts)
    local tpl = [[
Demonstrating variable substitution; the options affect which syntax is
recognized as a variable:

text text text only
text $(var1) text

$(var1) text text text $(var2)
$(var2) «var1» «var2»

Demonstrating table expansion:

-- table begin
    ${atable}
-- table end

Demonstrating iterator expansion:

-- iterable begin
    ${lineGen}
-- iterable end

Demonstrating decorated iterator expansion:

-- iterable begin
    ${lineGen2}
-- iterable end

text text text $(var2)
$(var2) text text text
$(var1) «var1»
]]

    env.var1    = env.var1 or "__DEF1"
    env.var2    = env.var2 or "__DEF2"
    env.atable  = env.atable or {"table line1", "table line2", "", "table line4"}
    env.lineGen = function() return ipairs(env.atable) end
    env.lineGen2= function() return engine.lineDecorator( env.lineGen, "", ";") end -- the two strings are a prefix and suffix

    opts = opts or {}
    local ok, res = engine.parse(tpl, opts, env)
    if ok then
        ok, res = res.evaluate()
        if not ok then
            res = table.concat(res, "\n")
        end
    end
    return ok, res
end

local opts = {xtendStyle = true}  -- the variables will be those within «»
local env  = { var1="myVar1", var2="myVar2" } -- do not pass 'atable', use the default

local ok, res = test(env, opts)
if not ok then
  print("Error: " .. res)
else
  print(res)
end


