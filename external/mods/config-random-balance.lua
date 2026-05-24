local function clamp(value, min_value, max_value)
  return math.max(min_value, math.min(max_value, value))
end


-- WORKS BUT EXTREMELY HIGH DMG THO.
-- local function reward_function(last)
--   local p1Life = Player(1).get.life()
--   local p2Life = Player(2).get.life()
-- 
--   local p1Damage = Player(1).get.receiveddamage()
--   local p2Damage = Player(2).get.receiveddamage()
-- 
--   -- 0 = perfectly even health, 1000 = one player basically untouched while other is dead
--   local healthDiff = math.abs(p1Life - p2Life)
-- 
--   -- Low health difference => +1, high health difference => -1
--   local balanceReward = map_range(healthDiff, 0, 1000, 1, -1)
-- 
--   -- Small bonus when damage is happening between steps.
--   -- Uses `last`, which SBLIB updates after reward calculation.
--   local activityBonus = 0
--   if last and last.p1_receivedDmg and last.p2_receivedDmg then
--     local damageDelta =
--       math.max(0, p1Damage - last.p1_receivedDmg) +
--       math.max(0, p2Damage - last.p2_receivedDmg)
--     activityBonus = clamp(map_range(damageDelta, 0, 40, 0, 0.08), 0, 0.08)
--   end
-- 
--   return clamp(balanceReward + activityBonus, -1, 1)
-- end


local function reward_function()
  local p1Life = Player(1).get.life()
  local p2Life = Player(2).get.life()
  local p1Atk = Player(1).get.attackmul()
  local p2Atk = Player(2).get.attackmul()

  local lifeGap = (p2Life - p1Life) / 1000
  local attackGap = (p1Atk - p2Atk) / 2.9
  local handicapAlignment = lifeGap * attackGap
  local closeness = 1 - math.abs(lifeGap)

  -- Reward good handicap direction, while still preferring close matches.
  return clamp(handicapAlignment * 2.4 + closeness * 0.35, -1, 1)
end

local function apply_atkmul(n, action)
  local p = Player(n)
  local impact = 0.04
  local change = action * impact
  local current = p.get.attackmul()
  p.set.attackmul(clamp(current + change, 0.1, 3.0))
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
  name = "ikemen-random-balance-v1",
  endpoint = "http://localhost:3000",
  description = "Random CPU balance reward with independent attack multiplier actions",
  reward_function = reward_function,
  frame_step_interval = 10,
  print_step_summary = true,
  allow_overwrite = true,
  allow_rename = false,
  post_request_function = post_request_function,
  train_every = 512,
  state = {
    { "p1_life",      Player(1).get.life,      { 0, 1000 } },
    { "p2_life",      Player(2).get.life,      { 0, 1000 } },
    { "p1_attackMul", Player(1).get.attackmul, { 0.1, 3.0 } },
    { "p2_attackMul", Player(2).get.attackmul, { 0.1, 3.0 } },
    { "round_time",   roundtime,               { 0, 5940 } },
    { "p1_power",     Player(1).get.power,     { 0, 1000.0 } },
    { "p2_power",     Player(2).get.power,     { 0, 1000.0 } },
    { "p1_receivedDmg", Player(1).get.receiveddamage },
    { "p2_receivedDmg", Player(2).get.receiveddamage },
    { "p1_score", Player(1).get.score, { 0, 20000 } },
    { "p2_score", Player(2).get.score, { 0, 20000 } },
  },
  actions = {
    { "p1_atkmul", function(v) return apply_atkmul(1, v) end },
    { "p2_atkmul", function(v) return apply_atkmul(2, v) end }
  },
  hyperparameters = {
    gamma = 0.95,
    lambda = 0.95,
    epsilon_clip = 0.3,
    critic_weight = 0.5,
    batch_size = 8,
    learning_rate = 0.001,
    epochs = 4,
    entropy_weight = 0.05,
    clip_grad = 0.5
  },
  log = log
}
