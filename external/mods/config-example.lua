local function clamp(value, min_value, max_value)
  return math.max(min_value, math.min(max_value, value))
end

-- LIFE DIFFERENCE
local function life_diff()
  return Player(1).get.life() - Player(2).get.life()
end

-- REWARD FUNCTION
local function reward_function(last)
  local p1 = Player(1).get.life()
  local p2 = Player(2).get.life()

  local current_diff = math.abs(p1 - p2)

  -- Smooths life difference over time to reduce noisy reward spikes
  local smoothed_diff = (last.smoothedDiff * 0.90) + (current_diff * 0.10)

  -- Positive when the match becomes more balanced over time
  local improvement = last.smoothedDiff - smoothed_diff

  -- Measures total damage dealt this step to encourage active fights
  local total_damage = (last.p1Life - p1) + (last.p2Life - p2)

  -- Higher when both players have similar remaining health
  local closeness = 1.0 - clamp(smoothed_diff / 1000,0,1)

   -- Base reward
  local reward = 0.0

  -- Rewards the agent when the life gap decreases over time
  if improvement > 0 then
    reward = reward + (improvement * 0.030)
  else
    reward = reward + (improvement * 0.010)
  end

  -- Gives continuous reward for maintaining close matches
  reward = reward + (closeness * 0.004)

  -- Encourages active combat instead of passive stalling
  if total_damage > 0 then
    reward = reward + math.min(total_damage / 500,0.004)
  else
    reward = reward - 0.003
  end

  -- Measures how far balancing changes deviate from neutral values
  local intervention =
    math.abs(Player(1).get.attackmul() - 1.0) +
    math.abs(Player(2).get.attackmul() - 1.0)

  -- Penalizes excessive balancing to avoid overly artificial matches
  reward = reward - (intervention * intervention * 0.0004)

  -- Gives extra reward if the match finishes in a balanced state
  if p1 <= 0 or p2 <= 0 then
    reward = reward + (closeness * 0.08)
  end

  -- Clamping reward between -1 and 1 since ppo likes this
  return clamp(reward, -1.0, 1.0)
end

-- Snapshot of the last state
local function last()

  local diff =
    math.abs(
      Player(1).get.life() -
      Player(2).get.life()
    )

  return {
    p1Life = Player(1).get.life(),
    p2Life = Player(2).get.life(),
    smoothedDiff = diff
  }

end

local function apply_balance(value)
  local action = value or 0
  local p1 = Player(1)
  local p2 = Player(2)

  -- Current value of in game attackmul
  local p1Current = clamp(p1.get.attackmul(),0.5,2.0)
  local p2Current = clamp(p2.get.attackmul(),0.5,2.0)

  -- Simple life difference of players
  local diff_signed = life_diff()
  local diff = math.abs(diff_signed)

  -- NORMALIZED DIFFERENCE
  -- Uses 700 instead of full 1000 HP so balancing reaches maximum strength
  -- earlier, allowing meaningful intervention before a match becomes unwinnable
  local normalized = clamp(diff / 700, 0.0, 1.0)

  -- Increases balancing strength exponentially as the life gap becomes larger
  local strength = normalized * normalized * 0.45

  -- DEADZONE
  if diff < 35 then
    strength = 0.0
  end

  -- Target is the target value we will be manipulating and start at current value
  local p1Target = p1Current
  local p2Target = p2Current

  --------------------------------------------------------------
  -- RL POLICY ACTIONS (BUFF NERF SYSTEM)
  --------------------------------------------------------------
  --  1  = BUFF LOSER
  --  0  = NO INTERVENTION
  -- -1  = NERF WINNER
  --------------------------------------------------------------
  if diff_signed > 0 then
    -- P1 WINNING
    if action == -1 then
      -- NERF WINNER
      p1Target = p1Target - strength
    elseif action == 1 then
      -- BUFF LOSER
      p2Target = p2Target + strength
    end
  elseif diff_signed < 0 then
    -- P2 WINNING
    if action == -1 then
      -- NERF WINNER
      p2Target = p2Target - strength
    elseif action == 1 then
      -- BUFF LOSER
      p1Target = p1Target + strength
    end
  end

  -- Slowly moves attack multipliers back toward default values over time
  local neutral_decay = 0.003
  p1Target = p1Target + ((1.0 - p1Target) * neutral_decay)
  p2Target = p2Target + ((1.0 - p2Target) * neutral_decay)

  -- This damping gradually pulls back the correction force toward neutral values to
  ---- reduce overshooting
  local damping = 1.0 - clamp(diff / 600, 0.0, 0.65)
  local damping_strength = 0.08
  p1Target = p1Target + ((1.0 - p1Target) * damping * damping_strength)
  p2Target = p2Target +((1.0 - p2Target) * damping * damping_strength)

  -- Light smoothing blends old and new values to prevent 
  ---- sudden balancing spikes or jitter
  p1Target = (p1Current * 0.15) + (p1Target * 0.85)
  p2Target = (p2Current * 0.15) + (p2Target * 0.85)

  -- Clamping dmg to prevent extreme changes
  p1Target = clamp(p1Target, 0.5, 2.0)
  p2Target = clamp(p2Target, 0.5, 2.0)

  p1.set.attackmul(p1Target)
  p2.set.attackmul(p2Target)

end


local function post_request_function(endpoint_string,content_type_string,payload)
return httppost(endpoint_string,content_type_string,payload)
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
  frame_step_interval = 1,
  print_step_summary = true,
  allow_overwrite = true,
  allow_rename = false,
  post_request_function = post_request_function,
  train_every = 512,
  last = last,
  state = {
    {"p1_life",function() return Player(1).get.life() end,{ 0, 1000 }},
    {"p2_life",function() return Player(2).get.life() end,{ 0, 1000 }},
    {"life_diff",function() return life_diff() end,{ -1000, 1000 }},
    {"abs_life_diff",function() return math.abs(life_diff()) end,{ 0, 1000 }},
    {"p1_attackMul",function() return Player(1).get.attackmul() end,{ 0.5, 2.0 }},
    {"p2_attackMul",function() return Player(2).get.attackmul() end,{ 0.5, 2.0 }},
  },
  actions = {{"balance",function(v) apply_balance (v) end}},
  hyperparameters = {
    gamma = 0.995,
    learning_rate = 0.00005,
    epochs = 4,
    entropy_weight = 0.020
  },
  log = log
}