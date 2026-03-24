local thisModule = {}

function thisModule.do_load_fail_on_error(engine, case)
    local ok, ret = engine.tload(case.tpl, case.opts, case.env, case.included)
    if not ok then
        print(table.concat(ret, "\n"))
        error("Test case "..case.id.." failed while loading the template", 2)
    end
    return ret
end

function thisModule.do_eval_fail_on_error(loaded_template, opts)
    local ok, ret = loaded_template.evaluate(opts)
    if not ok then
        print(table.concat(ret, "\n"))
        error("Test case failed while evaluating the template", 2)
    end
    return ret
end

function thisModule.do_loadeval_fail_on_error(engine, case)
    local ret = thisModule.do_load_fail_on_error(engine, case)
    return thisModule.do_eval_fail_on_error(ret, case.opts)
end

function thisModule.dotest(engine, case)
    local ok, ret, expanded = engine.tload(case.tpl, case.opts, case.env, case.included)
    if not ok then
        print(table.concat(ret, "\n"))
        error("Test case "..case.id.." failed while loading the template")
    end
    local text
    ok, text = ret.evaluate(case.opts)
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


function thisModule.dotest_expect_load_error(engine, case)
    local ok, ret, expanded = engine.tload(case.tpl, case.opts, case.env, case.included)
    if ok then
        error("Test case "..case.id.." failed: syntax error expected but not raised")
    end
    return ok, ret, expanded
end

function thisModule.dotest_expect_eval_error(engine, case)
    local ok, ret, expanded = engine.tload(case.tpl, case.opts, case.env, case.included)
    if not ok then
        error("Test case "..case.id.." failed: unexpected load-time error")
    end
    ok, ret = ret.evaluate()
    if ok then
        error("Test case "..case.id.." failed: evaluation error expected but not raised")
    end
    return ok, ret, expanded
end

return thisModule

