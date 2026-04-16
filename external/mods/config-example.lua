local function get_player(n)
  player(n)
  return {
    life = life(),
    attackmul = attackmul()
  }
end
-- Reward encourage equal life. For balanced game
local function reward_function()
  local p1_life, p2_life = get_player(1).life, get_player(2).life
  local max = math.max(p1_life, p2_life)
  local min = math.min(p1_life, p2_life)
  local diff = max - min
  local reward = 1000 - diff
  local timePunishment = (getRoundTime() - timeremaining()) / 10
  local highAtkReward = (get_player(1).attackmul + get_player(2).attackmul) * 100

  return get_player(1).attackmul * 10 -- Punish for time to encourage faster matches
  -- return reward - timePunishment + highAtkReward -- Punish for time to encourage faster matches
end

local function apply_attack_mul(n, value)
  if player(n) then
    local atkMul = attackmul()
    local calc = atkMul + (value * 0.1)
    -- Clamps attack at 0.01 and rounding to avoid infinitely long decimals
    calc = math.max(0.01, calc)
    SBLIB.round(calc, 3)
    setAttackMul(calc)
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
  print_RL_step_summary = true,
  allow_overwrite = true,
  allow_rename = false,
  post_request_function = post_request_function,
  train_every = 512,
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
  hyperparameters = {},
  learning_rate = 0.001,
  gamma = 1,
  batch_size = 256,
  grad_clip = 10.0,

}
