-- Personal word and phrase exclusions, configured in wanxiang.custom.yaml.
local filter = {}

local function clean(text)
    return text:gsub("^\239\187\191", ""):match("^%s*(.-)%s*$")
end

local function escape_pattern(text)
    return (text:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

local function read_lines(filename, consume)
    if not filename or filename == "" then return end
    local directories = {rime_api.get_user_data_dir(), rime_api.get_shared_data_dir()}
    for _, directory in ipairs(directories) do
        local file = io.open(directory .. "/" .. filename, "r")
        if file then
            for line in file:lines() do
                line = clean(line)
                if line ~= "" and line:sub(1, 1) ~= "#" then consume(line) end
            end
            file:close()
            return
        end
    end
    log.error("personal_word_filter: cannot read " .. filename)
end

function filter.init(env)
    env.blocked_words = {}
    env.rules = {}
    env.decisions = {}
    env.decision_count = 0
    local config = env.engine.schema.config
    local words = config:get_list("personal_word_filter/blocked_words")
    if words then
        for i = 0, words.size - 1 do
            local word = words:get_value_at(i)
            if word then env.blocked_words[clean(word.value):lower()] = true end
        end
    end
    read_lines(config:get_string("personal_word_filter/word_file"), function(word)
        env.blocked_words[word:lower()] = true
    end)
    read_lines(config:get_string("personal_word_filter/rules_file"), function(line)
        local mode, term, exceptions = line:match("^(%S+)\t([^\t]+)\t?(.*)$")
        if not mode or (mode ~= "contains" and mode ~= "word") then
            log.error("personal_word_filter: invalid rule: " .. line)
            return
        end
        term = clean(term):lower()
        if term == "" then return end
        local rule = {mode = mode, term = term, exceptions = {}}
        if mode == "word" then
            rule.pattern = "%f[A-Za-z0-9_]" .. escape_pattern(term) .. "%f[^A-Za-z0-9_]"
        end
        for exception in exceptions:gmatch("[^|]+") do
            table.insert(rule.exceptions, escape_pattern(clean(exception):lower()))
        end
        table.insert(env.rules, rule)
    end)

    -- Check traditional candidates with the same rules; preserve displayed text.
    if Opencc then
        local ok, converter = pcall(Opencc, "t2s.json")
        if ok then env.to_simplified = converter end
    end
end

local function matches_rule(text, rule)
    local function matches(value)
        if rule.mode == "word" then return value:find(rule.pattern) ~= nil end
        return value:find(rule.term, 1, true) ~= nil
    end
    if not matches(text) then return false end
    for _, exception in ipairs(rule.exceptions) do
        text = text:gsub(exception, " ")
    end
    return matches(text)
end

local function is_blocked(text, env)
    local cached = env.decisions[text]
    if cached ~= nil then return cached end
    local normalized = text
    if env.to_simplified then
        normalized = env.to_simplified:convert(text) or text
    end
    normalized = normalized:lower()
    local blocked = env.blocked_words[normalized] == true
    if not blocked then
        for _, rule in ipairs(env.rules) do
            if matches_rule(normalized, rule) then
                blocked = true
                break
            end
        end
    end
    if env.decision_count >= 4096 then
        env.decisions = {}
        env.decision_count = 0
    end
    env.decisions[text] = blocked
    env.decision_count = env.decision_count + 1
    return blocked
end

function filter.func(input, env)
    for candidate in input:iter() do
        if not is_blocked(candidate.text, env) then yield(candidate) end
    end
end

function filter.fini(env)
    env.blocked_words = nil
    env.rules = nil
    env.decisions = nil
    env.to_simplified = nil
end

return filter
