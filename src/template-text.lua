---
-- This modules exposes function(s) to evaluate textual templates, that is,
-- text which contain references to variables or expressions, or even Lua code
-- statements.
-- For example:
--    local engine = require "template-text"
--    local ok, loaded = engine.tload("Hello $(whom)", {}, {whom="Marco"})
--    ok, text = loaded.evaluate()
--    print(text) -- Hello Marco
-- For more examples see the readme and the `src/sample/` folder.
--
-- Similar programs are usually referred to as "templat[e|ing]
-- engines" or "pre-processors" (like the examples on the Lua user-wiki this
-- module is largely inspired from).
--
-- Briefly, the format for the templates is the following: regular text in the
-- template is copied verbatim, while expressions in the form `$(<var>)` are
-- replaced with the textual representation of `<var>`, which must be
-- evaluatable in the given environment.
-- Finally, lines starting with `@` are interpreted entirely as Lua code.
-- For more information see the readme file and the samples.
--
-- The module's local functions are for internal use.
--
-- The "public", "exported" functions
-- are those documented as `module.<...>`. These are the fields of the table
-- returned by the module, which you get by `require`ing it.
--
-- @module template-text
-- @author Marco Frigerio

local function tp(t) for k,v in pairs(t) do print(k,v) end end

--- @return an iterator over the lines of the given string
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
  elseif type(lines) ~= 'function' then
    error("the given argument must be a table or an iterator factory (was " .. type(lines) .. ")", 2)
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
-- generator, such as a `ipairs`.
-- The second and last argument are strings, both optional.
--
-- Sample usage:
--
--    local t = {"a","b","c","d"}
--    for i,v in lineDecorator( function() return ipairs(t) end, "--- ", " ###") do
--      print(i,v)
--    end
--
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


--- Parses a line from a Lua error message trying to extract the line number and
-- the error description.
--
-- This function is tailored for errors that may arise when loading and
-- executing a user template.
--
-- @return A table with two fields, the linenumber (`linenum`) and the error
--  message (`msg`). The line number is set to -1 when it could not be
--  extracted.
--
local function getErrorAndLineNumber(lua_error_msg)
  local match_pattern = "%[.+%]:(%d+): (.*)" -- tries to match "[...]:<number>: <msg>"
  local line, errormsg = lua_error_msg:match(match_pattern)
  if line == nil then
    return { linenum=-1, msg=lua_error_msg }
  else
    return { linenum=tonumber(line), msg=errormsg }
  end
end




--- Error handler to be used with `xpcall`. For internal use.
--
-- Uses `getErrorAndLineNumber` on each line of the original error message as
-- well as the stacktrace, in the attempt of providing good information about
-- the problem.
-- @return A table with two fields: `cause` and `stacktrace`. The first is the
--  return value of `getErrorAndLineNumber` invoked with the error message.
--  The second is an array, whose elements are the return value of
--  `getErrorAndLineNumber` for each line of the stacktrace where a line
--  number could be extracted.
--
local function errHandler(e)
  local ret = {
    cause = getErrorAndLineNumber(e),
    stacktrace = {}
  }
  local stacktrace = debug.traceback()
  --print("-----")print(e) print(stacktrace)print("------")

  for entry in stacktrace:gmatch("(.-)\n") do -- for every line
    local err = getErrorAndLineNumber(entry)
    if err.linenum ~= -1 then
      table.insert(ret.stacktrace, err)
    end
  end
  return ret
end

--- Constructs the error trace, a sequence or error messages.
--
-- @param trace The table holding the sequence (array) of messages
-- @param expanded_template The `ExpandedTemplate` table in which the error
--   occurred
-- @param error_line_num The number of the line of code where the error
--   occurred
-- @param indent The current value of indentation for the formatting of
--   the error messages
local function build_error_trace(trace, expanded_template, error_line_num, indent)
    local indent = indent or ""
    local function _put(line)
        table.insert(trace, indent .. line)
    end
    local target = expanded_template.line_of_code_to_source[error_line_num]
    if target == nil then
        _put("Internal error: could not back track the given line number "..error_line_num)
        --tp(expanded_template.line_of_code_to_source)
        return
    end
    --print(target, error_line_num)
    --tp(expanded_template.line_of_code_to_source)

    if type(target) == "number" then -- it is a normal line number, referring to the source
        _put("at line " .. target .. ":  >>> " .. expanded_template.source[target] .. " <<<")
    end
end

--- Executes the parsed template function. For internal use.
--
-- @param raw_eval_f The function returned by Lua's `load` on the code
--   obtained from the template
-- @param template The `ExpandedTemplate` table
-- @param env The environment (table) that the template was loaded with
-- @param opts A table with options:
--   @param opts.returnTable if true, the return value is an array of
--   text lines, otherwise a single string.
-- @param env_override An optional table that overrides matching entries
--   in the bound environment
--
-- @return A boolean flag indicating success
-- @return In case of success, the text of the evaluated template, as a single
--  string or as an array of lines. In case of failure, an array of lines with
--  error information.
--
local function evaluate(raw_eval_f, template, env, opts, env_override)
    if env_override ~= nil then
        for k,v in pairs(env_override) do
            env[k] = v
        end
    end
    local mytostring = (env.mytostring or tostring)
    env.table  = (env.table or table)
    env.pairs  = (env.pairs or pairs)
    env.ipairs = (env.ipairs or ipairs)
    env.__insertLines = insertLines
    env.__str = function(arg, arg_identifier_in_caller)
        if arg==nil then
            local expr_name = arg_identifier_in_caller or "<??>"
            error(string.format("Expression '%s' is undefined in the current environment", expr_name), 2)
        end
        local text = mytostring(arg)
        if type(text) ~= "string" then
            error("The given 'mytostring' function did not return a string")
        end
        return text
    end
    local ok, ret = xpcall(raw_eval_f, errHandler)
    if not ok then
        local myerror = {}
        table.insert(myerror, "Template evaluation failed: " .. ret.cause.msg)
        if ret.cause.linenum ~= -1 then
            build_error_trace(myerror, template, ret.cause.linenum)
        end
        if ret.stacktrace then
            table.insert(myerror, "Possible stacktrace:")
            for i,entry in ipairs(ret.stacktrace) do
                if entry.linenum ~= -1 then
                    build_error_trace(myerror, template, entry.linenum)
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


--- Generates the rendering code from a user template.
--
-- This is the function that "implements the syntax" of this template
-- engine.
local function expand(template, opts)
    local opts   = opts or {}
    local indent = string.rep(' ', (opts.indent or 0))

    -- Define the matching pattern for the variables, depending on options.
    -- The matching pattern reads in general as: <text><expr to capture><string position>
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
    local included = {}
    local line_of_code_to_source = {}
    local lineOfCode = nil
    for line in lines(template) do
        -- save the user template as an array of lines of text, for easy references
        table.insert(source, line)

        -- CODE statements
        -- Look for a '@' ignoring blanks (%s) at the beginning of the line
        -- If it's there, copy the string following the '@'
        local s,e = line:find("^%s*@")
        if s then
            lineOfCode = line:sub(e+1)
            goto line_parsed
        end

        -- TABLE inclusion
        -- Look for the specials '${..}', which must be alone in the line
        do
          local tableIndent, tableVarName = line:match("^([%s]*)${(.*)}[%s]*$")
          if tableVarName ~= nil then
              -- Preserve the indentation used for the "${..}" in the original template.
              -- "Sum" it to the global indentation passed here as an option.
              if tableVarName == "" then
                  lineOfCode = string.format("table.insert(text, %q)", indent .. tableIndent)
              else
                  lineOfCode = string.format("__insertLines(text, %s, %q)", tableVarName, indent..tableIndent)
              end
              goto line_parsed
          end
        end

        -- VARIABLEs or expressions
        -- Look for references to expressions, in the current line.
        -- Ultimately we have to build a _string_ which is a valid Lua expression
        -- that concatenates strings (!); something like
        -- '"   " .. "text" .. __str(var, "var") .. "more text"'
        do
          local subexpr = {}
          local lastindex = 1
          local c = 1
          local expression = nil
          for text, expr, index in line:gmatch(varMatch.pattern) do
            expression = varMatch.extract(expr)
            if expression ~= "" then
              subexpr[c] = string.format("%q .. __str(%s, %q)", text, expression, expression)
              -- we store the match as string '"<text>" .. __str(<expr>, "<expr>")'
              -- note that <text> may be empty.
            else
              -- there was a match, but an empty expression, like 'bla bla $()'
              subexpr[c] = string.format("%q", text)
            end
            lastindex = index
            c = c + 1
          end
          if c > 1 then
            -- Add the remaining part of the line (no further variable)
            expression = line:sub(lastindex)
            if expression ~= "" then
              subexpr[c] = string.format("%q", expression)
            end
            -- Concatenate the subexpressions into a single one, prepending the
            -- indentation if it is not empty.
            expression = table.concat(subexpr, ' .. ')
            if indent ~= "" then
              expression = string.format("%q", indent) .. ' .. ' .. expression
            end
          else
            -- No match of any '$()', thus we just add the whole line
            -- Note that we can do string concatenation now and not defer it to
            -- evaluation time (meaning we create '"<indent> <line>"' rather
            -- than '"<indent>" .. "<line>"', as we do above)
            expression = string.format("%q", indent .. line)
          end

          lineOfCode = "table.insert(text, " .. expression .. ")"
        end

        ::line_parsed::
        table.insert(chunk, lineOfCode)
        line_of_code_to_source[#chunk] = #source
    end
    if template:sub(-1) == "\n" then
        table.insert(chunk, "table.insert(text, \"\") -- to preserve the line terminator at EOF")
    end
    table.insert(chunk, "return text")
    return
    --- An expanded template, resulting from `expand`()
    -- @table ExpandedTemplate
    -- @field source The original template text
    -- @field code The Lua source code generated from the template
    --   (as text). This is the code that is run when "evaluating" the
    --   template. Inspecting this is useful for debugging or to
    --   understand how the process works.
    -- @field included A by-name map of the expanded included templates
    -- @field line_of_code_to_source A int-to-int map, from line of code
    --  to the corresponding line in the source template
    {
        source = source,
        code = chunk,
        included = included,
        line_of_code_to_source = line_of_code_to_source,
    }
end


--- Loads the given text-template and binds it to the given environment.
--
-- This function produces an object (`LoadResult`) that can be evaluated
-- into the final text. It checks for syntax errors and tries to produce
-- precise error messages.
--
-- @param template the text-template, as a string
-- @param opts non-mandatory options, a table with these fields:
--   @param opts.indent  number of blanks to be prepended before every output
--   line; this applies to the whole template, relative indentation between
--   different lines is preserved
--   @param opts.xtendStyle  if true, variables are matched with the pattern
--   `«<var>»` - instead of the default `$(<var>)`
-- @param env A table which shall define all the upvalues being referenced in
--   the given template
--
-- @return A boolean indicating success/failure (true/false).
-- @return In case of success, a table `LoadResult` whose primary field is a
--  function to actually evaluate the template into text. In case of errors, a
--  string with information about the error, including a line number, when
--  possible.
--
-- This function internally calls `expand`() and then Lua's `load`().
--
local function tload(template, opts, env)
    local expanded = expand(template, opts)
    local eval_env = env or {}

    local compiled, msg = load(table.concat(expanded.code, "\n"), "user template", "t", eval_env)
    if compiled==nil then
        local error_data = getErrorAndLineNumber(msg)
        local errormsg = {"Syntax error in the template: " .. error_data.msg}
        if error_data.linenum ~= -1 then
            build_error_trace(errormsg, expanded, error_data.linenum)
        end
        return false, errormsg, expanded
    end

  return true,
  --- A parsed template, bound to an evaluation environment, as returned by `tload`.
  -- @table LoadResult
  -- @field env The same environment given to `tload` by the caller
  -- @field template The resulting `ExpandedTemplate`
  -- @field evaluate The function to actually evaluate the template. This is
  --  a closure of the internal `evaluate` that only takes the `opts` and
  --  `env_override` arguments; see their description in `evaluate`.
  {
    env = eval_env,
    template = expanded,
    raw_eval_funct = compiled, -- TODO remove?
    evaluate = function(opts, env_override) return evaluate(compiled, expanded, eval_env, opts, env_override) end,
  },
  expanded -- to have the same number of return values as in the error case
end







local public_api = {

    --- Loads a template: this is the main function of the module.
    --
    -- See the docs of the local function `tload` which has the same
    -- signature.
    -- @return `LoadResult`
    -- @function module.tload
    tload = tload,

  --- Deprecated. Evaluates the given textual template.
  --
  -- Deprecated, included for backwards compatibility with the older version of
  -- this module.
  -- It is equivalent to call `tload` first, and then `evaluate()` on the
  -- result.
  -- @function module.template_eval
  template_eval = function(tpl, env, opts)
    local ok, ret = tload(tpl, opts, env)
    if ok then
        ok, ret = ret.evaluate(opts)
    end
    if not ok then
        ret = table.concat(ret, "\n")
    end
    return ok,ret -- always <boolean>,<text>
  end,

    --- Adds prefix/suffix to the text produced by an existing iterator.
    -- @function module.lineDecorator
    -- @see lineDecorator
    lineDecorator = lineDecorator,

    expand = expand,

}


return public_api


