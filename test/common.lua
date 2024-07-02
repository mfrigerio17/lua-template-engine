local function do_load_fail_on_error(engine, case)
    local ok, ret = engine.tload(case.tpl, case.opts, case.env, case.included)
    if not ok then
        print(table.concat(ret, "\n"))
        error("Test case "..case.id.." failed while loading the template", 2)
    end
    return ret
end

local function do_eval_fail_on_error(loaded_template, opts)
    local ok, ret = loaded_template.evaluate(opts)
    if not ok then
        print(table.concat(ret, "\n"))
        error("Test case failed while evaluating the template", 2)
    end
    return ret
end

local function do_loadeval_fail_on_error(engine, case)
    local ret = do_load_fail_on_error(engine, case)
    return do_eval_fail_on_error(ret, case.opts)
end

local function dotest(engine, case)
    local ok, ret, expanded = engine.tload(case.tpl, case.opts, case.env, case.included)
    if not ok then
        print(table.concat(ret, "\n"))
        error("Test case "..case.id.." failed while loading the template")
    end
    local text
    ok, text = ret.evaluate()
    if not ok then
        print(table.concat(text, "\n"))
        error("Test case "..case.id.." failed while evaluating the template")
    end
    if text ~= case.expected then
        --for i = 1, #text do
            --io.write(text:sub(i,i))
            --io.write(string.byte(text:sub(i,i)))
            --io.write(" ")
        --end
        --io.write("\n")
        --for i = 1, #case.expected do
            --io.write(case.expected:sub(i,i))
            --io.write(string.byte(case.expected:sub(i,i)))
            --io.write(" ")
        --end
        --io.write("\n")
        --print(table.concat(expanded.code,"\n")) -- for further debugging
        print("--returned--")print(text)
        print("--expected--")print(case.expected)print("-----")
        error("Test case "..case.id.." failed: evaluated template does not match the expected value")
    end
    return ret, text
end



return {
    dotest = dotest,
    do_load_fail_on_error = do_load_fail_on_error,
    do_eval_fail_on_error = do_eval_fail_on_error,
    do_loadeval_fail_on_error = do_loadeval_fail_on_error,
}

