local function clamp(value, min_value, max_value)
  return math.max(min_value, math.min(max_value, value))
end

----------------------------------------------------------------
-- LIFE DIFFERENCE
----------------------------------------------------------------

local function life_diff()
  return Player(1).get.life() - Player(2).get.life()
end

----------------------------------------------------------------
-- REWARD FUNCTION
----------------------------------------------------------------

local function reward_function(last)

  local p1 = Player(1).get.life()
  local p2 = Player(2).get.life()

  local current_diff =
    math.abs(p1 - p2)

  --------------------------------------------------------------
  -- TEMPORAL SMOOTHING
  --------------------------------------------------------------

  local smoothed_diff =
    (last.smoothedDiff * 0.90) +
    (current_diff * 0.10)

  --------------------------------------------------------------
  -- TRUE IMPROVEMENT SIGNAL
  --------------------------------------------------------------

  local improvement =
    last.smoothedDiff - smoothed_diff

  --------------------------------------------------------------
  -- DAMAGE
  --------------------------------------------------------------

  local total_damage =
    (last.p1Life - p1) +
    (last.p2Life - p2)

  --------------------------------------------------------------
  -- CLOSENESS
  --------------------------------------------------------------

  local closeness =
    1.0 - clamp(
      smoothed_diff / 1000,
      0,
      1
    )

  --------------------------------------------------------------
  -- BASE REWARD
  --------------------------------------------------------------

  local reward = 0.0

  --------------------------------------------------------------
  -- PRIMARY LEARNING SIGNAL
  --------------------------------------------------------------

  reward =
    reward + (improvement * 0.015)

  --------------------------------------------------------------
  -- HEAVY PENALTY FOR MAKING THINGS WORSE
  --------------------------------------------------------------

  if improvement < 0 then
    reward =
      reward + (improvement * 0.030)
  end

  --------------------------------------------------------------
  -- SMALL BALANCE BONUS
  --------------------------------------------------------------

  reward =
    reward + (closeness * 0.004)

  --------------------------------------------------------------
  -- DAMAGE INCENTIVE
  --------------------------------------------------------------

  if total_damage > 0 then
    reward =
      reward + math.min(
        total_damage / 500,
        0.004
      )
  else
    reward =
      reward - 0.003
  end

  --------------------------------------------------------------
  -- INTERVENTION PENALTY
  --------------------------------------------------------------

  local intervention =
    math.abs(Player(1).get.attackmul() - 1.0) +
    math.abs(Player(2).get.attackmul() - 1.0)

  reward =
    reward - (
      intervention * intervention * 0.006
    )

  --------------------------------------------------------------
  -- TERMINAL BONUS
  --------------------------------------------------------------

  if p1 <= 0 or p2 <= 0 then

    reward =
      reward + (closeness * 0.08)

  end

  --------------------------------------------------------------
  -- NORMALIZATION
  --------------------------------------------------------------

  return clamp(reward, -1.0, 1.0)

end

----------------------------------------------------------------
-- LAST STATE SNAPSHOT
----------------------------------------------------------------

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

----------------------------------------------------------------
-- ACTION APPLICATION
----------------------------------------------------------------

local function apply_balance(value)

  --------------------------------------------------------------
  -- PPO ACTION
  --------------------------------------------------------------
  -- PPO ONLY CONTROLS MAGNITUDE
  -- NEVER DIRECTION
  --------------------------------------------------------------

  local action =
    math.abs(
      clamp(value or 0, -1, 1)
    )

  local p1 = Player(1)
  local p2 = Player(2)

  --------------------------------------------------------------
  -- CURRENT VALUES
  --------------------------------------------------------------

  local p1Current =
    clamp(
      p1.get.attackmul(),
      0.75,
      1.25
    )

  local p2Current =
    clamp(
      p2.get.attackmul(),
      0.75,
      1.25
    )

  --------------------------------------------------------------
  -- LIFE DIFFERENCE
  --------------------------------------------------------------

  local diff_signed =
    life_diff()

  local diff =
    math.abs(diff_signed)

  --------------------------------------------------------------
  -- NONLINEAR STRENGTH
  --------------------------------------------------------------

  local normalized =
    clamp(diff / 400, 0.0, 1.0)

  local strength =
    normalized * normalized * 0.12

  --------------------------------------------------------------
  -- DEADZONE
  --------------------------------------------------------------

  if diff < 35 then
    strength = 0.0
  end

  --------------------------------------------------------------
  -- DELTA
  --------------------------------------------------------------
  -- ALWAYS POSITIVE
  --------------------------------------------------------------

  local delta =
    action * strength

  --------------------------------------------------------------
  -- TARGET VALUES
  --------------------------------------------------------------

  local p1Target =
    p1Current

  local p2Target =
    p2Current

  --------------------------------------------------------------
  -- AUTO-DIRECTIONAL BALANCING
  --------------------------------------------------------------

  if diff_signed > 0 then

    ------------------------------------------------------------
    -- P1 WINNING
    -- NERF P1
    -- BUFF P2
    ------------------------------------------------------------

    p1Target =
      p1Target - delta

    p2Target =
      p2Target + delta

  elseif diff_signed < 0 then

    ------------------------------------------------------------
    -- P2 WINNING
    -- BUFF P1
    -- NERF P2
    ------------------------------------------------------------

    p1Target =
      p1Target + delta

    p2Target =
      p2Target - delta

  end

  --------------------------------------------------------------
  -- RETURN TO NEUTRAL
  --------------------------------------------------------------

  local neutral_decay = 0.08

  p1Target =
    p1Target +
    ((1.0 - p1Target) * neutral_decay)

  p2Target =
    p2Target +
    ((1.0 - p2Target) * neutral_decay)

  --------------------------------------------------------------
  -- OVERSHOOT DAMPING
  --------------------------------------------------------------

  local damping =
    1.0 - clamp(diff / 300, 0.0, 0.85)

  p1Target =
    p1Target +
    ((1.0 - p1Target) * damping * 0.25)

  p2Target =
    p2Target +
    ((1.0 - p2Target) * damping * 0.25)

  --------------------------------------------------------------
  -- LOW PASS FILTER
  --------------------------------------------------------------

  p1Target =
    (p1Current * 0.65) +
    (p1Target * 0.35)

  p2Target =
    (p2Current * 0.65) +
    (p2Target * 0.35)

  --------------------------------------------------------------
  -- HARD CLAMP
  --------------------------------------------------------------

  p1Target =
    clamp(p1Target, 0.75, 1.25)

  p2Target =
    clamp(p2Target, 0.75, 1.25)

  --------------------------------------------------------------
  -- APPLY
  --------------------------------------------------------------

  p1.set.attackmul(p1Target)
  p2.set.attackmul(p2Target)

end

----------------------------------------------------------------
-- HTTP
----------------------------------------------------------------

local function post_request_function(
  endpoint_string,
  content_type_string,
  payload
)
  return httppost(
    endpoint_string,
    content_type_string,
    payload
  )
end

----------------------------------------------------------------
-- LOGGING
----------------------------------------------------------------

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

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------

return {

  name = "ikemen-balanced-ppo-v17-fixed-direction",

  endpoint = "http://localhost:3000",

  description =
    "Magnitude-only PPO directional balancing",

  reward_function = reward_function,

  frame_step_interval = 1,

  print_step_summary = true,

  allow_overwrite = true,

  allow_rename = false,

  post_request_function =
    post_request_function,

  --------------------------------------------------------------
  -- TRAINING
  --------------------------------------------------------------

  train_every = 512,

  last = last,

  ----------------------------------------------------------------
  -- STATE
  ----------------------------------------------------------------

  state = {

    {
      "p1_life",
      function()
        return Player(1).get.life()
      end,
      { 0, 1000 }
    },

    {
      "p2_life",
      function()
        return Player(2).get.life()
      end,
      { 0, 1000 }
    },

    {
      "life_diff",
      function()
        return life_diff()
      end,
      { -1000, 1000 }
    },

    {
      "abs_life_diff",
      function()
        return math.abs(life_diff())
      end,
      { 0, 1000 }
    },

    {
      "p1_attackMul",
      function()
        return Player(1).get.attackmul()
      end,
      { 0.75, 1.25 }
    },

    {
      "p2_attackMul",
      function()
        return Player(2).get.attackmul()
      end,
      { 0.75, 1.25 }
    },
  },

  ----------------------------------------------------------------
  -- ACTIONS
  ----------------------------------------------------------------

  actions = {
    {
      "balance",
      function(v)
        apply_balance(v)
      end
    }
  },

  ----------------------------------------------------------------
  -- PPO HYPERPARAMETERS
  ----------------------------------------------------------------

  hyperparameters = {

    gamma = 0.995,

    learning_rate = 0.00005,

    epochs = 4,

    --------------------------------------------------------------
    -- HIGHER ENTROPY
    --------------------------------------------------------------

    entropy_weight = 0.015
  },

  log = log
}