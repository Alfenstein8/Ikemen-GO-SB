  -- Reward encourage equal life. For balanced game
  local function reward_function()
      local max = math.max(get_p1_life(), get_p2_life())
      local min = math.min(get_p1_life(), get_p2_life())
      local diff = max-min
      local reward = 1000 - diff
      return (reward - 500)
  end

  local function apply_attack_mul_p1 (value)
    if player(1) then
      local atkMul = attackmul()
      local calc = atkMul + (value * 0.1)
      -- Clamps attack at 0.01 and rounding to avoid infinitely long decimals
      calc = math.max(0.01, calc)
      SBLIB.round(calc,3)
      setAttackMul(calc)
    end
  end

  local function apply_attack_mul_p2 (value)
    if player(2) then
      local atkMul = attackmul()
      local calc = atkMul + (value * 0.1)
      -- Clamps attack at 0.01 and rounding to avoid infinitely long decimals
      calc = math.max(0.01, calc)
      SBLIB.round(calc,3)
      setAttackMul(calc)
    end
  end

  function get_p1_life ()
    if player(1) then
      return life()
    end
  end

  function get_p2_life ()
    if player(2) then
      return life()
    end
  end

  function get_p1_attackMul ()
    if player(1) then
      return attackmul()
    end
  end

  function get_p2_attackMul ()
    if player(2) then
      return attackmul()
    end
  end

  function post_request_function (endpoint_string, content_type_string, payload)
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
        {"p1_life", get_p1_life, {0,1000}},
        {"p1_attackMul", get_p1_attackMul, {0,5}},
        {"p2_life", get_p2_life, {0,1000}},
        {"p2_attackMul", get_p2_attackMul, {0,5}},
      },
      actions = {
        {"apply_attack_mul_p1", apply_attack_mul_p1},
        {"apply_attack_mul_p2", apply_attack_mul_p2},
      },
      hyperparameters = {},
      learning_rate = 0.01
  }
