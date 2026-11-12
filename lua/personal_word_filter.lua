-- Academic vocabulary priority and personal candidate exclusions.
local filter = {}

local plain_pinyin = {
    ["ā"] = "a", ["á"] = "a", ["ǎ"] = "a", ["à"] = "a",
    ["ō"] = "o", ["ó"] = "o", ["ǒ"] = "o", ["ò"] = "o",
    ["ē"] = "e", ["é"] = "e", ["ě"] = "e", ["è"] = "e",
    ["ī"] = "i", ["í"] = "i", ["ǐ"] = "i", ["ì"] = "i",
    ["ū"] = "u", ["ú"] = "u", ["ǔ"] = "u", ["ù"] = "u",
    ["ü"] = "v", ["ǖ"] = "v", ["ǘ"] = "v", ["ǚ"] = "v", ["ǜ"] = "v",
    ["ń"] = "n", ["ň"] = "n", ["ǹ"] = "n", ["ḿ"] = "m",
}

local function add_academic_word(index, code, word)
    local entry = index[code]
    if not entry then
        entry = {words = {}, count = 0}
        index[code] = entry
    end
    if not entry.words[word] then entry.count = entry.count + 1 end
    entry.words[word] = true
end

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

local function load_priority_dictionary(env, filename, abbreviations)
    read_lines(filename, function(line)
        local word, pinyin = line:match("^([^\t]+)\t([^\t]+)\t%d+$")
        if not word or utf8.len(word) < 2 then return end
        pinyin = pinyin:gsub(utf8.charpattern, plain_pinyin)
        if pinyin:find("[^a-z ]") then return end
        local syllables = {}
        for syllable in pinyin:gmatch("%S+") do
            table.insert(syllables, syllable)
        end
        local function add(code)
            add_academic_word(env.academic_index, code, word)
            local alternate = code:gsub("([nl])ve", "%1ue")
            if alternate ~= code then
                add_academic_word(env.academic_index, alternate, word)
            end
        end
        add(table.concat(syllables))
        -- Only the small, explicitly configured personal phrase dictionary
        -- gets mixed full/initial codes. Academic abbreviations remain native.
        if not abbreviations or #syllables > 6 then return end
        local function expand(position, prefix)
            if position > #syllables then add(prefix); return end
            local syllable = syllables[position]
            expand(position + 1, prefix .. syllable)
            if #syllable > 1 then expand(position + 1, prefix .. syllable:sub(1, 1)) end
            local initial = syllable:match("^[zcs]h")
            if initial and #syllable > 2 then expand(position + 1, prefix .. initial) end
        end
        expand(1, "")
    end)
end

function filter.init(env)
    env.blocked_words = {}
    env.rules = {}
    env.decisions = {}
    env.decision_count = 0
    env.academic_index = {}
    env.fixed_codes = {}
    local config = env.engine.schema.config
    local fixed_dictionary = config:get_string("custom_phrase/user_dict")
    if fixed_dictionary and config:get_string("custom_phrase/db_class") == "stabledb" then
        read_lines(fixed_dictionary .. ".txt", function(line)
            local word, code = line:match("^([^\t]+)\t([^\t]+)\t")
            if code then
                env.fixed_codes[code] = env.fixed_codes[code] or {}
                env.fixed_codes[code][word] = true
            end
        end)
    end
    for _, source in ipairs({{"academic_dictionaries", false}, {"preferred_dictionaries", true}}) do
        local dictionaries = config:get_list("personal_word_filter/" .. source[1])
        if dictionaries then
            for i = 0, dictionaries.size - 1 do
                local filename = dictionaries:get_value_at(i)
                if filename then load_priority_dictionary(env, filename.value, source[2]) end
            end
        end
    end
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

local function academic_matches(env)
    local context = env.engine.context
    if context.composition:empty() or context:get_option("ascii_mode") then return end
    local segment = context.composition:back()
    if not segment:has_tag("abc") then return end
    local code = context.input:sub(segment.start + 1, segment._end)
    local fixed = env.fixed_codes[code]
    if code:find("[^a-z' ]") then return nil, segment.start, segment._end, fixed end
    code = code:gsub("[' ]", "")
    return env.academic_index[code], segment.start, segment._end, fixed
end

function filter.func(input, env)
    local matches, start_pos, end_pos, fixed_input = academic_matches(env)
    if not matches and not fixed_input then
        for candidate in input:iter() do
            if not is_blocked(candidate.text, env) then yield(candidate) end
        end
        return
    end

    local fixed, academic, ordinary = {}, {}, {}
    local found = {}
    local remaining = matches and matches.count or 0
    local fixed_found = not fixed_input
    local inspected = 0
    local flushed = false
    local function flush()
        -- Preserve native order within each group, including learned preferences.
        for _, candidate in ipairs(fixed) do yield(candidate) end
        for _, candidate in ipairs(academic) do yield(candidate) end
        for _, candidate in ipairs(ordinary) do yield(candidate) end
        fixed, academic, ordinary = nil, nil, nil
        flushed = true
    end

    for candidate in input:iter() do
        inspected = inspected + 1
        if not is_blocked(candidate.text, env) then
            if flushed then
                yield(candidate)
            else
                local text = candidate.text
                if env.to_simplified then text = env.to_simplified:convert(text) or text end
                local is_academic = matches and matches.words[text]
                    and candidate.start == start_pos and candidate._end == end_pos
                if is_academic and not found[text] then
                    found[text] = true
                    remaining = remaining - 1
                end
                local is_fixed = candidate.type == "user_table" or (fixed_input
                    and (fixed_input[candidate.text] or fixed_input[text]))
                if is_fixed then
                    table.insert(fixed, candidate)
                    fixed_found = true
                elseif is_academic then
                    table.insert(academic, candidate)
                else
                    table.insert(ordinary, candidate)
                end
            end
        end
        -- Bound look-ahead; stop as soon as all exact academic matches are found.
        if not flushed and ((remaining == 0 and fixed_found) or inspected >= 128) then flush() end
    end
    if not flushed then flush() end
end

function filter.fini(env)
    env.blocked_words = nil
    env.rules = nil
    env.decisions = nil
    env.to_simplified = nil
    env.academic_index = nil
    env.fixed_codes = nil
end

return filter
