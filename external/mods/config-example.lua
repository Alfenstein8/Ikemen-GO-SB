local function clamp(value, min_value, max_value)
  return math.max(min_value, math.min(max_value, value))
end

local function life_diff()
  return Player(1).get.life() - Player(2).get.life()
end

local function map_range(value, in_min, in_max, out_min, out_max)
  return (value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end
local function reward_function()
  local p1Life = Player(1).get.life()
  local p2Life = Player(2).get.life()
  local diff = math.abs(p1Life - p2Life)
  local reward = map_range(1000 - diff, 0, 1000, 0, 1)
  return clamp(reward, 0, 1)
end

-- Snapshot of the last state
local function last()
  return {
    p1Life = Player(1).get.life(),
    p2Life = Player(2).get.life(),
  }
end

local function apply_atkmul(n, action)
  local p = Player(n)
  local impact = 3
  local change = action * impact
  local current = p.get.attackmul()
  p.set.attackmul(current + change)
end


local function post_request_function(endpoint_string, content_type_string, payload)
  return httppost(endpoint_string, content_type_string, payload)
end
local function log()
  local log_state = {}
  for n, v in pairs(Player(1).get) do
    log_state["p1_" .. n] = v
  end
  for n, v in pairs(Player(2).get) do
    log_state["p2_" .. n] = v
  end
  return log_state
end
return {
  name = "ikemen-test-v20",
  endpoint = "http://localhost:3000",
  description = "Buff Nerf RL system",
  reward_function = reward_function,
  frame_step_interval = 10,
  print_step_summary = true,
  allow_overwrite = true,
  allow_rename = false,
  post_request_function = post_request_function,
  train_every = 512,
  last = last,
  state = {
    { "p1_life",      Player(1).get.life,      { 0, 1000 } },
    { "p2_life",      Player(2).get.life,      { 0, 1000 } },
    { "p1_attackMul", Player(1).get.attackmul, { 0.1, 2.0 } },
    { "p2_attackMul", Player(2).get.attackmul, { 0.1, 2.0 } },
  },
  actions = {
    { "p1_atkmul", function(v) return apply_atkmul(1, v) end },
    { "p2_atkmul", function(v) return apply_atkmul(2, v) end }
  },
  hyperparameters = {
    gamma = 0.995,
    learning_rate = 0.00005,
    epochs = 4,
    entropy_weight = 0.020
  },
  log = log
}
