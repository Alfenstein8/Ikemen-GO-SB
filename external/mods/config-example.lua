local function clamp(value, min_value, max_value)
  return math.max(min_value, math.min(max_value, value))
end

local function life_diff()
  return Player(1).get.life() - Player(2).get.life()
end

local function reward_function(last)

  local current = life_diff()
  local previous = last.diff or current
  local delta = math.abs(previous) - math.abs(current)

  if math.abs(delta) < 25 then
    delta = 0
  end

  local reward = delta / 150

  if math.abs(current) < 50 then
    reward = reward + 0.02
  end

  return reward
end

local function last()
  return {
    diff = life_diff()
  }
end

local function last()
  return {
    diff = math.abs(life_diff())
  }
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

local function approach(current, target, amount)
  return current + ((target - current) * amount)
end

return {
  name = "ikemen-test",
  endpoint = "http://localhost:3000",
  description = "Trying something",
  reward_function = reward_function,
  frame_step_interval = 1,
  print_step_summary = true,
  allow_overwrite = true,
  allow_rename = false,
  post_request_function = post_request_function,
  train_every = 512,
  last = last,
  state = {
    {"life_diff",function() return life_diff() end,{ -1000, 1000 }},
    {"p1_attackMul",function() return Player(1).get.attackmul() end,{ 0.5, 2.0 }},
    {"p2_attackMul",function() return Player(2).get.attackmul() end,{ 0.5, 2.0 }}
  },
  actions = {
  {
    "p1_attackmul",
    function(v)

      -- current values
      local p1 = Player(1).get.attackmul()
      local p2 = Player(2).get.attackmul()

      -- apply action
      p1 = clamp(p1 + (v * 0.01), 0.5, 2.0)

      -- decay both toward 1.0
      p1 = approach(p1, 1.0, 0.02)
      p2 = approach(p2, 1.0, 0.02)

      -- set values
      Player(1).set.attackmul(p1)
      Player(2).set.attackmul(p2)
    end
  },
  {
    "p2_attackmul",
    function(v)

      local p1 = Player(1).get.attackmul()
      local p2 = Player(2).get.attackmul()

      p2 = clamp(p2 + (v * 0.01), 0.5, 2.0)

      p1 = approach(p1, 1.0, 0.02)
      p2 = approach(p2, 1.0, 0.02)

      Player(1).set.attackmul(p1)
      Player(2).set.attackmul(p2)
    end
  }
  },
  hyperparameters = {
    gamma = 0.99,
    learning_rate = 0.0001,
    epochs = 4,
    entropy_weight = 0.02
  },
  log = log
}
