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

  --------------------------------------------------------------
  -- CURRENT DIFFERENCE
  --------------------------------------------------------------

  local current_diff =
    math.abs(p1 - p2)

  --------------------------------------------------------------
  -- STRONG TEMPORAL SMOOTHING
  --------------------------------------------------------------

  local smoothed_diff =
    (last.smoothedDiff * 0.95) +
    (current_diff * 0.05)

  --------------------------------------------------------------
  -- IMPROVEMENT SIGNAL
  --------------------------------------------------------------

  local improvement =
    (last.smoothedDiff - smoothed_diff)

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
  -- SMALL IMPROVEMENT SIGNAL
  --------------------------------------------------------------

  reward =
    reward + (improvement * 0.0025)

  --------------------------------------------------------------
  -- PRIMARY OBJECTIVE:
  -- KEEP FIGHT CLOSE
  --------------------------------------------------------------

  reward =
    reward + (closeness * 0.020)

  --------------------------------------------------------------
  -- DAMAGE INCENTIVE
  --------------------------------------------------------------

  if total_damage > 0 then
    reward =
      reward + math.min(
        total_damage / 400,
        0.006
      )
  else
    reward = reward - 0.001
  end

  --------------------------------------------------------------
  -- INTERVENTION PENALTY
  --------------------------------------------------------------

  local intervention =
    math.abs(Player(1).get.attackmul() - 1.0) +
    math.abs(Player(2).get.attackmul() - 1.0)

  --------------------------------------------------------------
  -- STRONGER PENALTY
  -- PREVENTS OSCILLATION
  --------------------------------------------------------------

  reward =
    reward - (
      intervention * intervention * 0.02
    )

  --------------------------------------------------------------
  -- TERMINAL BONUS
  --------------------------------------------------------------

  if p1 <= 0 or p2 <= 0 then
    reward =
      reward + (closeness * 0.15)
  end

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
  local action =
    clamp(value or 0, -1, 1)

  local p1 = Player(1)
  local p2 = Player(2)

  --------------------------------------------------------------
  -- CURRENT VALUES
  --------------------------------------------------------------

  local p1Current =
    p1.get.attackmul()

  local p2Current =
    p2.get.attackmul()

  --------------------------------------------------------------
  -- LIFE DIFFERENCE
  --------------------------------------------------------------

  local diff =
    math.abs(life_diff())

  --------------------------------------------------------------
  -- CONTROL STRENGTH
  --------------------------------------------------------------

  local strength =
    clamp(
      diff / 1200,
      0.0,
      0.12
    )

  --------------------------------------------------------------
  -- DEADZONE
  --------------------------------------------------------------

  if diff < 80 then
    strength = 0.0
  end

  --------------------------------------------------------------
  -- MOMENTARY IMPULSE
  --------------------------------------------------------------

  local impulse =
    action * strength

  --------------------------------------------------------------
  -- APPLY IMPULSE
  --------------------------------------------------------------

  local p1Next =
    p1Current + impulse

  local p2Next =
    p2Current - impulse

  --------------------------------------------------------------
  -- NATURAL DECAY BACK TO 1.0
  --------------------------------------------------------------

  local decay = 0.08

  p1Next =
    p1Next + ((1.0 - p1Next) * decay)

  p2Next =
    p2Next + ((1.0 - p2Next) * decay)

  --------------------------------------------------------------
  -- FINAL CLAMP
  --------------------------------------------------------------

  p1.set.attackmul(
    clamp(p1Next, 0.75, 1.25)
  )

  p2.set.attackmul(
    clamp(p2Next, 0.75, 1.25)
  )
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
  name = "ikemen-balanced-ppo-v13-damped",

  endpoint = "http://localhost:3000",

  description =
    "Damped PPO discrete fight balancing",

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

    learning_rate = 0.00003,

    epochs = 3,

    entropy_weight = 0.010
  },

  log = log
}