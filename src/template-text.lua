local function getErrorAndLineNumber(lua_error_msg)
  local match_pattern = "%[.+%]:(%d+): (.*)" -- ... :<number>: <msg>
  local line, errormsg = lua_error_msg:match(match_pattern)
  if line == nil then
    return { linenum=-1, msg=lua_error_msg }
  else
    return { linenum=tonumber(line), msg=errormsg }
  end
end



--- Compiles a chunk of code and sets the environment for subsequent evaluation.
-- @param chunk, the code as a string
-- @param env, the environment table
-- @return true or false depending on success
-- @return the compiled function in case of success, a table from
--    `getErrorAndLineNumber()` otherwise
local function load_chunk_and_bind_env(chunk, env)
    local compiled, msg = load(chunk, "user template", "t", env)
    if compiled==nil then
        return false, getErrorAndLineNumber(msg)
    else
        return true, compiled
    end
end




local function lines(s)
        if s:sub(-1)~="\n" then s=s.."\n" end
        return s:gmatch("(.-)\n")
end

--- Copy every string in the second argument into the first, prepending indentation.
-- The first argument must be a table. The second argument is either a table
-- itself (having strings as elements) or a function returning a factory of
-- a suitable iterator; for example, a function returning 'ipairs(t)', where 't'
-- is a table of strings, is a valid argument.
local insertLines = function(text, lines, totIndent)
  if lines == nil then
    error("nil argument given", 2)
  end
  local factory = lines
  if type(lines) == 'table' then
    factory = function() return ipairs(lines) end
  end
  for i,line in factory() do
    local lineadd = ""
    if line ~= "" then
      lineadd = totIndent .. line
    end
    table.insert(text, lineadd)
  end
end

--- Decorates an existing string iteration, adding an optional prefix and suffix.
-- The first argument must be a function returning an existing iterator
-- generator, such as a 'ipairs'.
-- The second and last argument are strings, both optional.
--
-- Sample usage:
--   local t = {"a","b","c","d"}
--   for i,v in ipairs(t) do
--     print(i,v)
--   end
--
--   for i,v in lineDecorator( function() return ipairs(t) end, "--- ", " ###") do
--     print(i,v)
--   end
local lineDecorator = function(generator, prefix, suffix)
  local opts = opts or {}
  local prefix = prefix or ""
  local suffix = suffix or ""
  local iter, inv, ctrl = generator( )

  return function()
    local i, line = iter(inv, ctrl)
    ctrl = i
    local retline = ""
    if line ~= nil then
      if line ~= "" then
        retline = prefix .. line .. suffix
      end
    end
    return i, retline -- nil or ""
  end
end


local function errHandler(e)
  -- Try to get the number of the line of the template that caused the error,
  -- parsing the text of the stacktrace. Note that the string here in the
  -- matching pattern should correspond to whatever is generated in the
  -- template_eval function, further down
  local ret = {
    cause = getErrorAndLineNumber(e)
  }
  local stacktrace = debug.traceback()
  --print(e) print(stacktrace)
  ret.stacktrace = {}
  for entry in stacktrace:gmatch("(.-)\n") do
    local err = getErrorAndLineNumber(entry)
    if err.linenum ~= -1 then
      table.insert(ret.stacktrace, err)
    end
  end
  return ret
end

local function evaluate(parsed_template, source, env, opts, env_override)
    if env_override ~= nil then
        for k,v in pairs(env_override) do
            env[k] = v
        end
    end
    env.table = (env.table or table)
    env.pairs = (env.pairs or pairs)
    env.ipairs = (env.ipairs or ipairs)
    env.__insertLines = insertLines
    env.__str = function(arg, arg_identifier_in_caller)
        if arg==nil then
            local expr_name = arg_identifier_in_caller or "<??>"
            error(string.format("Expression '%s' is undefined in the current environment", expr_name), 2)
        end
        return tostring(arg)
    end
    local ok, ret = xpcall(parsed_template, errHandler)
    if not ok then
        local ln = ret.cause.linenum - 1
        local myerror = {}
        table.insert(myerror, "Template evaluation failed: " .. ret.cause.msg)
        if ret.cause.linenum ~= -1 then
            table.insert(myerror, "\tat line " .. ln ..
                ":  >>> " .. source[ln] .. " <<<")
        end
        if ret.stacktrace then
            table.insert(myerror, "Possible stacktrace:")
            for i,entry in ipairs(ret.stacktrace) do
                ln = entry.linenum - 1
                if entry.linenum ~= -1 then
                    table.insert(myerror, "\t" .. entry.msg .. " - at line " .. ln ..
                        ":  >>> " .. source[ln] .. " <<<")
                end
            end
        end
    return false, myerror
    end

    local opts = opts or {}
    if not (opts.returnTable or false) then
    ret = table.concat(ret, "\n")
    end
    return ok, ret
end


--- Parse the given text-template.
-- Regular text in the template is copied verbatim, while expressions in the
-- form $(<var>) are replaced with the textual representation of <var>, which
-- must be defined in the given environment.
-- Finally, lines starting with @ are interpreted entirely as Lua code.
--
-- @param template the text-template, as a string
-- @param opts non-mandatory options
--        - indent: number of blanks to be prepended before every output line;
--          this applies to the whole template, relative indentation between
--          different lines is preserved
--        - xtendStyle: if true, variables are matched with this pattern "«<var>»"
-- @return The text of the evaluated template; if the option 'returnTable' is
--         set to true, though, the table with the sequence of lines of text is
--         returned instead
local function parse(template, opts, env)

  local opts    = opts or {}
  local indent  = string.format("%s", string.rep(' ', (opts.indent or 0) ) )

  -- Define the matching patter for the variables, depending on options.
  -- The matching pattern reads in general as: <text><var><string position>
  local varMatch = {
    pattern = "(.-)$(%b())()",
    extract = function(expr) return expr:sub(2,-2) end
  }
  if opts.xtendStyle then
    varMatch.pattern = "(.-)«(.-)»()"
    varMatch.extract = function(expr) return expr end
  end

  -- Generate a line of code for each line in the input template.
  -- The lines of code are also strings; we add them in the 'chunk' table.
  -- Every line is either the insertion in a table of a string, or a 1-to-1 copy
  --  of the code inserted in the template via the '@' character.
  local chunk = {"local text={}"}
  local source = {}
  local lineOfCode = nil
  for line in lines(template) do
    table.insert(source, line)
    -- Look for a '@' ignoring blanks (%s) at the beginning of the line
    -- If it's there, copy the string following the '@'
    local s,e = line:find("^%s*@")
    if s then
      lineOfCode = line:sub(e+1)
    else
      -- Look for the specials '${..}', which must be alone in the line
      local tableIndent, tableVarName = line:match("^([%s]*)${(.-)}[%s]*")
      if tableVarName ~= nil then
        -- Preserve the indentation used for the "${..}" in the original template.
        -- "Sum" it to the global indentation passed here as an option.
        local totIndent = string.format("%q", indent .. tableIndent)
        lineOfCode = "__insertLines(text, " .. tableVarName .. ", " .. totIndent .. ")"
      else
        -- Look for the template variables in the current line.
        -- All the matches are stored as strings '"<text>" .. <variable>'
        -- Note that <text> can be empty
        local subexpr = {}
        local lastindex = 1
        local c = 1
        for text, expr, index in line:gmatch(varMatch.pattern) do
          local expression = varMatch.extract(expr)
          if expression ~= "" then
            subexpr[c] = string.format("%q .. __str(%s, %q)", text, expression, expression)
          else
            subexpr[c] = string.format("%q", text)
          end
          lastindex = index
          c = c + 1
        end
        -- Add the remaining part of the line (no further variable) - or the
        -- entire line if no $() was found
        subexpr[c] = string.format("%q", line:sub(lastindex))

        -- Concatenate the subexpressions into a single one, prepending the
        -- indentation if it is not empty
        local expression = table.concat(subexpr, ' .. ')
        if expression~="\"\"" and indent~="" then
          expression = string.format("%q", indent) .. ' .. ' .. expression
        end

        lineOfCode = "table.insert(text, " .. expression .. ")"
      end
    end
    table.insert(chunk, lineOfCode)
  end
  table.insert(chunk, "return text")

  local rendering_code = table.concat(chunk, '\n')
  local eval_environment = env or {}
  local ok, parsed = load_chunk_and_bind_env(rendering_code, eval_environment)
  if not ok then
    local errormsg = "Syntax error in the template: " .. parsed.msg
    if parsed.linenum ~= -1 then
        errormsg = errormsg .. "\n\tat line " .. parsed.linenum ..
            ":  >>> " .. chunk[parsed.linenum] .. " <<<"
    end
    return false, errormsg
  end

  return true, {
    env = eval_environment,
    source = source,
    code = chunk,
    parsed = parsed,
    evaluate = function(opts, env_override) return evaluate(parsed, source, eval_environment, opts, env_override) end,
  }
end



return {
  parse = parse,
  -- for backwards compatibility:
  template_eval = function(tpl, env, opts)
    local ok, ret = parse(tpl, opts, env)
    if ok then
        ok, ret = ret.evaluate(opts)
        if not ok then
            ret = table.concat(ret, "\n")
        end
    end
    return ok,ret -- always <boolean>,<text>
  end,
  lineDecorator = lineDecorator
}





