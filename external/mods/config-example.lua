function get_player(n)
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

  local maxLife = 1000.0
  local life_diff = (p1.life - p2.life) / maxLife

  local mul_diff = (p1.attackmul - p2.attackmul) / 4.0

  local alignment = -(life_diff * mul_diff)

  local function mul_penalty(mul)
    if mul < 0.3 then return -0.5 * (0.3 - mul) / 0.3 end
    if mul > 3.5 then return -0.3 * (mul - 3.5) / 1.5 end
    return 0.0
  end

  local reward = alignment * 0.8
      + mul_penalty(p1.attackmul)
      + mul_penalty(p2.attackmul)

  return math.max(-1.0, math.min(1.0, reward))
end

function last()
  return {
    p1Life = get_player(1).life,
    p2Life = get_player(2).life,
    p1AttackMul = get_player(1).attackmul,
    p2AttackMul = get_player(2).attackmul
  }
end

local function apply_attack_mul(n, value)
  if player(n) then
    local atkMul = attackmul()
    local requested = atkMul + (value * 0.1)
    local calc = math.max(0.01, requested)
    local was_noop = (calc == atkMul)
    SBLIB.round(calc, 3)
    setAttackMul(calc)
    return was_noop
  end
end


function post_request_function(endpoint_string, content_type_string, payload)
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
    gamma = 0.99,
    learning_rate = 0.0003,
    epochs = 3,
    entropy_weight = 0.01,
    lambda = 0.95,
    epsilon_clip = 0.2,
    clip_grad = 0.5,
    batch_size = 64,
    critic_weight = 0.999
  }
}
