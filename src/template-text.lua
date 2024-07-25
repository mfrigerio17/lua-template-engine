---
-- This modules exposes function(s) to evaluate textual templates, that is,
-- text which contain references to variables or expressions, or even Lua code
-- statements.
-- For example:
--    local engine = require "template-text"
--    local ok, loaded = engine.tload("Hello $(whom)", {}, {whom="Marco"})
--    ok, text = loaded.evaluate()
--    print(text) -- Hello Marco
-- You can find more examples in this documentation's menu.
--
-- Similar programs are usually referred to as "templat[e|ing]
-- engines" or "pre-processors" (like the examples on the Lua user-wiki this
-- module is largely inspired from).
--
-- Briefly, the format for the templates is the following: regular text in the
-- template is copied verbatim, while expressions in the form `$(<var>)` are
-- replaced with the textual representation of `<var>`, which must be
-- evaluatable in the given environment.
-- Lines starting with `@` are interpreted entirely as Lua code.
-- For more information and more features see @{syntax_reference.md} and
-- the examples.
--
-- The module's local functions are for internal use, whereas
-- the "public" module's functions are those documented as `module.<...>`.
-- These are the fields of the table you get by `require`ing the module.
--
-- @module template-text
-- @author Marco Frigerio


local function tp(t) for k,v in pairs(t) do print(k,v) end end

local chunk_name_for_luas_load = "user template"

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
  -- try to match '[.."<chunk name>"]:<number>: <msg>'
  local match_pattern = "%[.*\""..chunk_name_for_luas_load.."\"%]:(%d+): (.*)"
  local line, errormsg = lua_error_msg:match(match_pattern)
  if line == nil then
    errormsg = string.gsub(lua_error_msg, "^[%s]+", "") -- remove blanks at the beginning
    return { linenum=-1, msg=errormsg }
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
  -- get the Lua stacktrace text, but remove the first line
  local stacktrace = string.gsub(debug.traceback(), "stack traceback:\n", "")
  --print("-----")print(e) print(stacktrace)print("------")

  for entry in stacktrace:gmatch("(.-)\n") do -- for every line
    if string.find(entry, "xpcall") then
      -- we care about errors in the evaluation of the template, that is
      -- anything that happened inside the call to xpcall. Therefore we
      -- do not care about the stacktrace up to xpcall itself.
      break
    end
    local err = getErrorAndLineNumber(entry)
    table.insert(ret.stacktrace, err)
  end
  return ret
end

--- Recursively constructs the error trace, a sequence or error messages.
--
-- Recursion is used due to the template inclusion feature: this
-- function tries to trace back the source of the error even in the case
-- of nested templates, at arbitrary depth (e.g. template t1 includes t2
-- which includes t3, ..., tn, and the error is in tn).
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
        _put("[your template]:" .. target .. ":  >>> " .. expanded_template.source[target] .. " <<<")
    else -- it is a reference to an included template
        local included = expanded_template.included[target]
        if included == nil then
            _put("Internal error: could not find the data of included template '" .. target .. "'")
            return
        end
        _put("in template '"..target.."' included at line "..
          included.at_line .. ":  >>> " .. expanded_template.source[included.at_line] .. " <<<")
        build_error_trace(trace, included.template, error_line_num - included.first_code_line + 1, indent.."  ")
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
            build_error_trace(myerror, template, ret.cause.linenum, "  ")
        end
        if ret.stacktrace then
            table.insert(myerror, "Possible stacktrace:")
            for i,entry in ipairs(ret.stacktrace) do
                -- If there is a line number, the entry refers to the
                -- user template itself. We then use the function that
                -- tracks the error through template nesting.
                -- Otherwise, we just copy the original message
                if entry.linenum ~= -1 then
                    build_error_trace(myerror, template, entry.linenum, "  ")
                else
                    table.insert(myerror, "  "..entry.msg)
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


local function parse_slashes_string(slashes)
    local slashes_count = string.len(slashes)
    return {
        count          = slashes_count,
        actual_chars   = string.rep("\\", math.floor(slashes_count/2)),
        escaping_active = (slashes_count % 2 == 1),
    }
end

--- Generates the rendering code from a user template.
--
-- This is the function that "implements the syntax" of this template
-- engine.
local function expand(template, opts, included_templates)
    local opts   = opts or {}
    local indent = string.rep(' ', (opts.indent or 0))
    local included_templates = included_templates or {}

    -- Define the matching pattern for the variables, depending on options.
    -- The matching pattern reads in general as: <text><expr to capture><string position>
    local varMatch = {
        pattern = "(.-)([\\]*)($(%b()))()",
        extract_argument = function(dollar_argument_match) return dollar_argument_match:sub(2,-2) end
    }
    if opts.xtendStyle then
      varMatch.pattern = "(.-)([\\]*)(«(.-)»)()"
      varMatch.extract_argument = function(brackets_argument_match) return brackets_argument_match end
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

        -- INCLUDED templates
        -- This is the only case where one source line introduces (in general)
        -- multiple lines of code.
        do
          local includeIndent, slashes, includedName = line:match("^([%s]*)(\\*)$<(.+)>[%s]*$")
          -- Note that the pattern is greedy (+), because template inclusion
          -- is anyway meant to be the only non-blank expression on the
          -- line. Also, we match anything (.) because the token will be
          -- used as a key in a table, and a key in lua can be any string

          if includedName ~= nil then
              slashes = parse_slashes_string(slashes)
              if slashes.count > 0 then
              -- note how we do not even need to check if there is an active slash
              -- quoting the $, because the mere presence of _any_ characters before
              -- $<> implies (according to our specs) that there is no match
                  lineOfCode = string.format("table.insert(text, %q)",
                      includeIndent .. slashes.actual_chars .. "$<" .. includedName .. ">")
                  goto line_parsed
              end

              if included_templates[includedName] == nil then
                  error("Referenced template '".. includedName .. "' was not given in the included templates parameter ")
              end
              local options = {}
              for k,v in pairs(opts) do options[k]=v end -- shallow table copy
              options.indent = (opts.indent or 0) + string.len(includeIndent)
              local expanded = expand(included_templates[includedName], options, included_templates)
              table.insert(chunk, "-- start included template '" ..includedName.. "'")
              local current_line_num = #chunk
              included[includedName] = {
                  name = includedName,
                  template = expanded,
                  at_line = #source,
                  first_code_line = current_line_num + 1
              }
              -- append the code of the included template
              -- note that we must skip the first and last line
              for i = 1, #expanded.code-2 do
                  table.insert(chunk, expanded.code[i+1])
                  line_of_code_to_source[current_line_num+i] = includedName
              end
              lineOfCode = "-- finish included template '" ..includedName.. "'"
              goto line_parsed
          end
        end

        -- TABLE inclusion
        -- Look for the specials '${..}', which must be alone in the line
        -- Preserve the indentation before '${..}' in the original template.
        do
          local tableIndent, slashes, tableVarName, trailingSpace = line:match("^([%s]*)(\\*)${(.*)}([%s]*)$")
          if tableVarName ~= nil then
              slashes = parse_slashes_string(slashes)
              if slashes.count > 0 then
              -- same as for template inclusion, the sole fact that there
              -- are some characters before the $, means no expansion.
              -- Thus we copy the line as it is, including trailing space
                  lineOfCode = string.format("table.insert(text, %q)",
                      indent .. tableIndent .. slashes.actual_chars .. "${" .. tableVarName .. "}" .. trailingSpace)
              elseif tableVarName == "" then
                  -- we have an empty argument, i.e. '${}' - preserve the indentation
                  lineOfCode = string.format("table.insert(text, %q)", indent .. tableIndent)
              else
                  lineOfCode = string.format("__insertLines(text, %s, %q)",
                      tableVarName, indent..tableIndent)
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
          for text, slashes, expr, argument, index in line:gmatch(varMatch.pattern) do
              slashes = parse_slashes_string(slashes)
              -- append the '\' inserted by the user:
              text = text .. slashes.actual_chars

              -- extract the evaluatable expression, as in "$(<this one>)" or "«<this one>»"
              expression = varMatch.extract_argument(argument)
              if slashes.escaping_active then
                  subexpr[c] = string.format("%q", text .. expr)
              elseif expression ~= "" then
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
              expression = string.format("%q .. %s", indent, expression)
            end
          else
            -- No match of any '$()', thus we just add the whole line
            -- Note that we can do string concatenation now and not defer it to
            -- evaluation time (meaning we create '"<indent> <line>"' rather
            -- than '"<indent>" .. "<line>"', as we do above).
            -- However, if the line itself is empty, we do not even use
            -- the indentation, to avoid inserting lines that contain
            -- only blanks. TODO this may be controllable by an option
              if line == "" then
                  expression = [[""]]
              else
                  expression = string.format("%q", indent .. line)
              end
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
    -- @field code The Lua source code generated from the template, as
    --  an array of strings. This is the code that is run when
    --  "evaluating" the template. Inspecting this is useful for
    --   debugging or to understand how the process works.
    -- @field included A by-name map of the expanded included templates
    -- @field line_of_code_to_source A int-to-int map, from line of code
    --  to the corresponding line in the source template (for internal
    --  use - this gets more complex in the case of included templates)
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
-- @param included_templates A by-name map of the templates that are
--   included by `template`. Optional.
--
-- @return A boolean indicating success/failure (true/false).
-- @return In case of success, a table `LoadResult` whose primary field is a
--  function to actually evaluate the template into text. In case of errors,
--  an array of strings with information about the error, including a
--  line number, when possible.
--
-- This function internally calls `expand`() and then Lua's `load`().
--
local function tload(template, opts, env, included_templates)
    local expanded = expand(template, opts, included_templates)
    local eval_env = env or {}

    local compiled, msg = load(table.concat(expanded.code, "\n"), chunk_name_for_luas_load, "t", eval_env)
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


