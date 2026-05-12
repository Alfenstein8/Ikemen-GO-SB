local SBLIB = {}
local config = {}
local last = {}
local stepCounter = 0
local done = false
local sb = {}
local log_file
local log_keys = {}

function SBLIB.get_steps()
    if not stepCounter then return end

    return stepCounter
end

-- Setup the config from a path
function SBLIB.setup_config_from_path(config_path)
    SBLIB.setup_config(require(config_path))
end

--- Skill Balancer Config Setup Function
--- @param config_object table
function SBLIB.setup_config(config_object)
    config = config_object

    if config.last then
        last = config.last()
    end

    local state_size = #config.state
    local action_size = #config.actions

    -- Setting up state names to get sent to server
    local state_names = {}
    for _, value in ipairs(config.state) do
        table.insert(state_names, value[1])
    end

    -- Setting up action names to get sent to server
    local action_names = {}
    for _, value in ipairs(config.actions) do
        table.insert(action_names, value[1])
    end

    -- Prepare the config with the variables the server needs
    local server_config = {
        name = config.name,
        description = config.description,
        state_size = state_size,
        state = state_names,
        action_size = action_size,
        actions = action_names,
        allow_overwrite = config.allow_overwrite,
        allow_rename = config.allow_rename,
        train_every = config.train_every,
        hyperparameters = config.hyperparameters,
        learning_rate = config.learning_rate
    }
    local json_encoded_string = sb.json.encode(server_config)
    local res = config.post_request_function(config.endpoint .. "/config", "application/json", json_encoded_string)

    -- Returns server responses and hyper param error if present
    local decoded_res = sb.json.decode(res)
    if decoded_res["message"] then
        print("Server response: ", decoded_res["message"])
    else
        if decoded_res["HPError"] then
            print(sb.color.fg.RED .. "Hyper parameter error:")
            print(decoded_res["HPError"])
            print(sb.color.reset)
        end
    end

    if config.log then
        os.execute("mkdir -p logs")
        local filename = os.date("logs/log_%Y_%m_%d_%H_%M_%S.csv")
        log_file = sb.log_setup(filename, config.log(), config.actions)
    end
end

---SBLIB Step Function (Runs every frame_step_interval)
--- Is responsible for stepping and preparing values for the server to use during RL
---@param frame integer
function SBLIB.step(frame)
    -- Checks if config is initialized and gets the game state
    if not config.frame_step_interval then return end
    if frame % config.frame_step_interval ~= 0 then return end
    local game_state = sb.get_game_state()
    if not game_state then return end
    local normalized_game_state = sb.normalize_game_state(game_state)

    stepCounter = stepCounter + 1

    -- Calculates reward from config.
    local reward = config.reward_function(last)

    if config.last then
        last = config.last()
    end

    ----------- CONNECTION TO THE SERVER STEP FUNCTION -------------------------------------
    local payload = {}
    payload.name = config.name
    payload.game_state = normalized_game_state
    payload.prev_reward = reward
    payload.done = done
    local json_encoded_payload = sb.json.encode(payload)
    local json_adjustment_actions = config.post_request_function(config.endpoint .. "/step", "application/json",
        json_encoded_payload)
    local reponse = sb.json.decode(json_adjustment_actions)
    local actions = reponse.action
    sb.apply_actions(actions)
    if config.print_step_summary == true then
        sb.print_step_summary(game_state, normalized_game_state, reward, actions, stepCounter)
    end

    if config.log then
        local action_map = {}
        for i, a in ipairs(config.actions) do
            action_map["a_" .. a[1]] = actions[i]
        end
        sb.log(log_file, config.log(), action_map, frame, stepCounter)
    end
    done = false
end

function SBLIB.done()
    done = true
end

function SBLIB.start()
    if config.last then
        last = config.last()
    end
end

function sb.log_setup(path, log_vars, actions)
    log_keys = { "Time", "Frame", "Step" }
    for k, _ in pairs(log_vars) do
        log_keys[#log_keys + 1] = k
    end
    for _, a in ipairs(actions) do
        log_keys[#log_keys + 1] = "a_" .. a[1]
    end

    local file = io.open(path, "a")
    if file then
        file:write(table.concat(log_keys, ",") .. "\n")
        file:flush()
    end
    return file
end

function sb.log(file, log_vars, actions, frame, step)
  if file then
    local parts = {}
    for _, k in ipairs(log_keys) do
      if k == "Time" then
        parts[#parts + 1] = tostring(os.time())
      elseif k == "Frame" then
        parts[#parts + 1] = tostring(frame)
      elseif k == "Step" then
        parts[#parts + 1] = tostring(step)
      elseif log_vars[k] then
        parts[#parts + 1] = tostring(log_vars[k]())
      else
        parts[#parts + 1] = tostring(actions[k] or "")
      end
    end
    file:write(table.concat(parts, ",") .. "\n")
    file:flush()
  end
end
--- SBLIB Apply Action function
--- Applies all action functions from the config in order of the action names calculating during config setup
--- Uses adjustment actions which is a vector of activations for certain actions.
--- 1 is increase, -1 is decrease and 0 is nochange
---@param adjustment_actions table
function sb.apply_actions(adjustment_actions)
    for index, value in ipairs(adjustment_actions) do
        config.actions[index][2](value)
    end
end


---SBLIB Get Game State Function
---Responsible for iterating over getters from config, which get the game state
---@return table
function sb.get_game_state()
    local game_state = {}
    -- Indexes over all getters for the game state variables
    for _, value in ipairs(config.state) do
        table.insert(game_state, value[2]())
    end
    return game_state
end


local auto_ranges = {}
function sb.auto_normalize(value, index)
    local range = auto_ranges[index]

    if not range then
        range = {min = value, max = value}
        auto_ranges[index] = range
    end

    if value < range.min then
        range.min = value
    end
    if value > range.max then
        range.max = value
    end

    if range.max == range.min then
        return 0
    end

    return sb.map_range(value, range.min, range.max, -1, 1)
end

function sb.normalize_game_state(game_state)
    local normalized_state = {}
    for index, _ in ipairs(config.state) do
        local v = game_state[index]
        if config.state[index][3] ~= nil then
            v = sb.map_range(v, config.state[index][3][1], config.state[index][3][2], -1, 1)
        else
            v = sb.auto_normalize(v, index)
        end
        table.insert(normalized_state, v)
    end
    return normalized_state
end

---Simple function for printing relevant variables in terminal
---@param game_state table
---@param reward number
---@param actions table
---@param stepFrame integer
function sb.print_step_summary(game_state, normalized_game_state, reward, actions, stepFrame)
    print()
    print("-------- Step Summary --------")
    print("Step: ", stepFrame)
    -- Print reward
    if reward ~= nil then
      print("Reward: " .. tostring(reward))
    end

    -- Print actions if provided
    if actions ~= nil then
      local arr = sb.string_from_array(actions)
      print("Action: " .. arr)
    end
    -- Print game state
    print("Game State:")
    for index, value in ipairs(config.state) do
      print(string.format("%15s: %-15f mapped: %9f", value[1], game_state[index], normalized_game_state[index]))
    end
end



------------ HELPER FUNCTIONS ------------------------

function sb.map_range(value, in_min, in_max, out_min, out_max)
    return (value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end

function sb.print_table(tbl)
    if type(tbl) ~= "table" then
        error("print_table expected table, got " .. type(tbl))
    end

    for k, v in pairs(tbl) do
        print(tostring(k) .. " = " .. tostring(v) .. " (" .. type(v) .. ")")
    end
end

function sb.string_from_array(arr)
    if type(arr) ~= "table" then
        error("print_array expected table, got " .. type(arr))
    end
    local str = "["
    for _, v in ipairs(arr) do
        str = str .. tostring(v) .. ", "
    end
    str = str:sub(1, -3) -- Remove the last comma and space
    str = str .. "]"
    return str
end

-- Embedded json library for encoding tables to JSON data
sb.json = (function()
    local json = { _version = "0.1.2" }

    -------------------------------------------------------------------------------
    -- Encode
    -------------------------------------------------------------------------------

    local encode

    local escape_char_map = {
    [ "\\" ] = "\\",
    [ "\"" ] = "\"",
    [ "\b" ] = "b",
    [ "\f" ] = "f",
    [ "\n" ] = "n",
    [ "\r" ] = "r",
    [ "\t" ] = "t",
    }

    local escape_char_map_inv = { [ "/" ] = "/" }
    for k, v in pairs(escape_char_map) do
    escape_char_map_inv[v] = k
    end


    local function escape_char(c)
    return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
    end


    local function encode_nil(val)
    return "null"
    end


    local function encode_table(val, stack)
    local res = {}
    stack = stack or {}

    -- Circular reference?
    if stack[val] then error("circular reference") end

    stack[val] = true

    if rawget(val, 1) ~= nil or next(val) == nil then
        -- Treat as array -- check keys are valid and it is not sparse
        local n = 0
        for k in pairs(val) do
        if type(k) ~= "number" then
            error("invalid table: mixed or invalid key types")
        end
        n = n + 1
        end
        if n ~= #val then
        error("invalid table: sparse array")
        end
        -- Encode
        for i, v in ipairs(val) do
        table.insert(res, encode(v, stack))
        end
        stack[val] = nil
        return "[" .. table.concat(res, ",") .. "]"

    else
        -- Treat as an object
        for k, v in pairs(val) do
        if type(k) ~= "string" then
            error("invalid table: mixed or invalid key types")
        end
        table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
        end
        stack[val] = nil
        return "{" .. table.concat(res, ",") .. "}"
    end
    end


    local function encode_string(val)
    return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
    end


    local function encode_number(val)
    -- Check for NaN, -inf and inf
    if val ~= val or val <= -math.huge or val >= math.huge then
        error("unexpected number value '" .. tostring(val) .. "'")
    end
    return string.format("%.14g", val)
    end


    local type_func_map = {
    [ "nil"     ] = encode_nil,
    [ "table"   ] = encode_table,
    [ "string"  ] = encode_string,
    [ "number"  ] = encode_number,
    [ "boolean" ] = tostring,
    }


    encode = function(val, stack)
    local t = type(val)
    local f = type_func_map[t]
    if f then
        return f(val, stack)
    end
    error("unexpected type '" .. t .. "'")
    end


    function json.encode(val)
    return ( encode(val) )
    end


    -------------------------------------------------------------------------------
    -- Decode
    -------------------------------------------------------------------------------

    local parse

    local function create_set(...)
    local res = {}
    for i = 1, select("#", ...) do
        res[ select(i, ...) ] = true
    end
    return res
    end

    local space_chars   = create_set(" ", "\t", "\r", "\n")
    local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
    local escape_chars  = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
    local literals      = create_set("true", "false", "null")

    local literal_map = {
    [ "true"  ] = true,
    [ "false" ] = false,
    [ "null"  ] = nil,
    }


    local function next_char(str, idx, set, negate)
    for i = idx, #str do
        if set[str:sub(i, i)] ~= negate then
        return i
        end
    end
    return #str + 1
    end


    local function decode_error(str, idx, msg)
    local line_count = 1
    local col_count = 1
    for i = 1, idx - 1 do
        col_count = col_count + 1
        if str:sub(i, i) == "\n" then
        line_count = line_count + 1
        col_count = 1
        end
    end
    error( string.format("%s at line %d col %d", msg, line_count, col_count) )
    end


    local function codepoint_to_utf8(n)
    -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
    local f = math.floor
    if n <= 0x7f then
        return string.char(n)
    elseif n <= 0x7ff then
        return string.char(f(n / 64) + 192, n % 64 + 128)
    elseif n <= 0xffff then
        return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
    elseif n <= 0x10ffff then
        return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
                        f(n % 4096 / 64) + 128, n % 64 + 128)
    end
    error( string.format("invalid unicode codepoint '%x'", n) )
    end


    local function parse_unicode_escape(s)
    local n1 = tonumber( s:sub(1, 4),  16 )
    local n2 = tonumber( s:sub(7, 10), 16 )
    -- Surrogate pair?
    if n2 then
        return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
    else
        return codepoint_to_utf8(n1)
    end
    end


    local function parse_string(str, i)
    local res = ""
    local j = i + 1
    local k = j

    while j <= #str do
        local x = str:byte(j)

        if x < 32 then
        decode_error(str, j, "control character in string")

        elseif x == 92 then -- `\`: Escape
        res = res .. str:sub(k, j - 1)
        j = j + 1
        local c = str:sub(j, j)
        if c == "u" then
            local hex = str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1)
                    or str:match("^%x%x%x%x", j + 1)
                    or decode_error(str, j - 1, "invalid unicode escape in string")
            res = res .. parse_unicode_escape(hex)
            j = j + #hex
        else
            if not escape_chars[c] then
            decode_error(str, j - 1, "invalid escape char '" .. c .. "' in string")
            end
            res = res .. escape_char_map_inv[c]
        end
        k = j + 1

        elseif x == 34 then -- `"`: End of string
        res = res .. str:sub(k, j - 1)
        return res, j + 1
        end

        j = j + 1
    end

    decode_error(str, i, "expected closing quote for string")
    end


    local function parse_number(str, i)
    local x = next_char(str, i, delim_chars)
    local s = str:sub(i, x - 1)
    local n = tonumber(s)
    if not n then
        decode_error(str, i, "invalid number '" .. s .. "'")
    end
    return n, x
    end


    local function parse_literal(str, i)
    local x = next_char(str, i, delim_chars)
    local word = str:sub(i, x - 1)
    if not literals[word] then
        decode_error(str, i, "invalid literal '" .. word .. "'")
    end
    return literal_map[word], x
    end


    local function parse_array(str, i)
    local res = {}
    local n = 1
    i = i + 1
    while 1 do
        local x
        i = next_char(str, i, space_chars, true)
        -- Empty / end of array?
        if str:sub(i, i) == "]" then
        i = i + 1
        break
        end
        -- Read token
        x, i = parse(str, i)
        res[n] = x
        n = n + 1
        -- Next token
        i = next_char(str, i, space_chars, true)
        local chr = str:sub(i, i)
        i = i + 1
        if chr == "]" then break end
        if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
    end
    return res, i
    end


    local function parse_object(str, i)
    local res = {}
    i = i + 1
    while 1 do
        local key, val
        i = next_char(str, i, space_chars, true)
        -- Empty / end of object?
        if str:sub(i, i) == "}" then
        i = i + 1
        break
        end
        -- Read key
        if str:sub(i, i) ~= '"' then
        decode_error(str, i, "expected string for key")
        end
        key, i = parse(str, i)
        -- Read ':' delimiter
        i = next_char(str, i, space_chars, true)
        if str:sub(i, i) ~= ":" then
        decode_error(str, i, "expected ':' after key")
        end
        i = next_char(str, i + 1, space_chars, true)
        -- Read value
        val, i = parse(str, i)
        -- Set
        res[key] = val
        -- Next token
        i = next_char(str, i, space_chars, true)
        local chr = str:sub(i, i)
        i = i + 1
        if chr == "}" then break end
        if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
    end
    return res, i
    end


    local char_func_map = {
    [ '"' ] = parse_string,
    [ "0" ] = parse_number,
    [ "1" ] = parse_number,
    [ "2" ] = parse_number,
    [ "3" ] = parse_number,
    [ "4" ] = parse_number,
    [ "5" ] = parse_number,
    [ "6" ] = parse_number,
    [ "7" ] = parse_number,
    [ "8" ] = parse_number,
    [ "9" ] = parse_number,
    [ "-" ] = parse_number,
    [ "t" ] = parse_literal,
    [ "f" ] = parse_literal,
    [ "n" ] = parse_literal,
    [ "[" ] = parse_array,
    [ "{" ] = parse_object,
    }


    parse = function(str, idx)
    local chr = str:sub(idx, idx)
    local f = char_func_map[chr]
    if f then
        return f(str, idx)
    end
    decode_error(str, idx, "unexpected character '" .. chr .. "'")
    end


    function json.decode(str)
    if type(str) ~= "string" then
        error("expected argument of type string, got " .. type(str))
    end
    local res, idx = parse(str, next_char(str, 1, space_chars, true))
    idx = next_char(str, idx, space_chars, true)
    if idx <= #str then
        decode_error(str, idx, "trailing garbage")
    end
    return res
    end


    return json
end)()



local color = { _NAME = "color" }
sb.color = color
local _M = color

local esc = string.char(27, 91)

local names = {'black', 'red', 'green', 'yellow', 'blue', 'pink', 'cyan', 'white'}
local hi_names = {'BLACK', 'RED', 'GREEN', 'YELLOW', 'BLUE', 'PINK', 'CYAN', 'WHITE'}

color.fg, color.bg = {}, {}

for i, name in ipairs(names) do
   color.fg[name] = esc .. tostring(30+i-1) .. 'm'
   _M[name] = color.fg[name]
   color.bg[name] = esc .. tostring(40+i-1) .. 'm'
end

for i, name in ipairs(hi_names) do
   color.fg[name] = esc .. tostring(90+i-1) .. 'm'
   _M[name] = color.fg[name]
   color.bg[name] = esc .. tostring(100+i-1) .. 'm'
end

local function fg256(_,n)
   return esc .. "38;5;" .. n .. 'm'
end

local function bg256(_,n)
   return esc .. "48;5;" .. n .. 'm'
end

setmetatable(color.fg, {__call = fg256})
setmetatable(color.bg, {__call = bg256})

color.reset = esc .. '0m'
color.clear = esc .. '2J'

color.bold = esc .. '1m'
color.faint = esc .. '2m'
color.normal = esc .. '22m'
color.invert = esc .. '7m'
color.underline = esc .. '4m'

color.hide = esc .. '?25l'
color.show = esc .. '?25h'

function color.move(x, y)
   return esc .. y .. ';' .. x .. 'H'
end

color.home = color.move(1, 1)

--------------------------------------------------

function color.chart(ch,col)
   local cols = '0123456789abcdef'

   ch = ch or ' '
   col = col or color.fg.black
   local str = color.reset .. color.bg.WHITE .. col

   for y = 0, 15 do
      for x = 0, 15 do
         local lbl = cols:sub(x+1, x+1)
         if x == 0 then lbl = cols:sub(y+1, y+1) end

         str = str .. color.bg.black .. color.fg.WHITE .. lbl
         str = str .. color.bg(x+y*16) .. col .. ch
      end
      str = str .. color.reset .. "\n"
   end
   return str .. color.reset
end

function color.test()
   print(color.reset .. color.bg.green .. color.fg.RED .. "This is bright red on green" .. color.reset)
   print(color.invert .. "This is inverted..." .. color.reset .. " And this isn't.")
   print(color.fg(0xDE) .. color.bg(0xEE) .. "You can use xterm-256 colors too!" .. color.reset)
   print("And also " .. color.bold .. "BOLD" .. color.normal .. " if you want.")
   print(color.bold .. color.fg.BLUE .. color.bg.blue .. "Miss your " .. color.fg.RED .. "C-64" .. color.fg.BLUE .. "?" .. color.reset)
   print("Try printing " .. color.underline .. _M._NAME .. ".chart()" .. color.reset)
end

return SBLIB
