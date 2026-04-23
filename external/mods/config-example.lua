local function get_player(n)
  player(n)
  return {
    life = life(),
    attackmul = attackmul()
  }
end

local function reward_function_simple(last)
  return (get_player(1).attackmul - last.p1AtkMul) * 10
end

local function reward_function(last)
  local p1 = get_player(1)
  local p2 = get_player(2)

  local d1 = last.p1Life - p1.life
  local d2 = last.p2Life - p2.life

  -- If no damage happened , return 0 (Neutral)
  if d1 <= 0 and d2 <= 0 then
    return 0
  end

  -- The player with more health should deal less damage
  local reward = 0

  -- If P1 deals damage to P2
  if d2 > 0 then
    if p1.life > p2.life then
      reward = reward + 0.1
    else
      reward = reward + 0.5
    end
  end

  -- If P2 deals damage to P1
  if d1 > 0 then
    if p2.life > p1.life then
      reward = reward + 0.1
    else
      reward = reward + 0.5
    end
  end

  if p1.attackmul > 3.0 or p2.attackmul > 3.0 then
    reward = reward - 0.2
  end

  return math.max(-1, math.min(1, reward))
end

local function last()
  return {
    p1Life = get_player(1).life,
    p2Life = get_player(2).life,
    p1AtkMul = get_player(1).attackmul,
    p2AtkMul = get_player(2).attackmul
  }
end

local function apply_attack_mul(n, value)
  if player(n) then
    local atkMul = attackmul()
    local calc = atkMul + (value * 0.1)
    -- Clamps attack at 0.01 and rounding to avoid infinitely long decimals
    calc = math.max(0.01, calc)
    Utils.round(calc, 3)
    setAttackMul(calc)
  end
end


local function post_request_function(endpoint_string, content_type_string, payload)
  -- Custom go post function.
  return httppost(endpoint_string, content_type_string, payload)
end

-- Basic setup for RL for ikemon go. All state vars are getters and application functions set game variables
return {
  name = "ikemon-test",
  endpoint = "http://localhost:3000",
  description = "Sample RL config",
  reward_function = reward_function,
  frame_step_interval = 20,
  print_step_summary = true,
  allow_overwrite = true,
  allow_rename = false,
  post_request_function = post_request_function,
  train_every = 512,
  last = last,
  state = {
    { "p1_life",      function() return get_player(1).life end,      { 0, 1000 } },
    { "p1_attackMul", function() return get_player(1).attackmul end, { 0, 5 } },
    { "p2_life",      function() return get_player(2).life end,      { 0, 1000 } },
    { "p2_attackMul", function() return get_player(2).attackmul end, { 0, 5 } },
  },
  actions = {
    { "apply_attack_mul_p1", function(v) apply_attack_mul(1, v) end },
    { "apply_attack_mul_p2", function(v) apply_attack_mul(2, v) end },
  },
  hyperparameters = {
    gamma = 0.95,
    learning_rate = 0.000005,
    epochs = 5,
    entropy_weight = 0.05
  },
}
