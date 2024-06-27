
local function dotest(engine, case)
    local ok, ret = engine.tload(case.tpl, case.opts, case.env, case.included)
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
        print("--returned--")print(text)
        print("--expected--")print(case.expected)print("-----")
        error("Test case "..case.id.." failed: evaluated template does not match the expected value")
    end
    return ret, text
end


return {
    dotest = dotest,
}
