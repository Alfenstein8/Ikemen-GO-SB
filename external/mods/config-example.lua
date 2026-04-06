  -- Reward encourage equal life. For balanced game
  local function reward_function()
      local diff = get_p1_life() - get_p2_life()
      -- Normalizing health
      local norm = diff / 1000
      
      -- Quadratic normalized difference
      local reward = norm * math.abs(norm)
      
      -- Clamp to [-10, 10]
      reward = math.max(-10, math.min(10, reward))
      return reward
  end

  local function apply_attack_mul_p1 (value) 
    if player(1) then
      local atkMul = attackmul()
      local calc = atkMul + (value * 0.001)  
      -- Clamps attack at 0.01 and rounding to avoid infinitely long decimals
      calc = math.max(0.01, calc)
      SBLIB.round(calc,3)
      setAttackMul(calc)
    end
  end

  local function apply_attack_mul_p2 (value)
    if player(2) then
      local atkMul = attackmul()
      local calc = atkMul + (value * 0.001) 
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


  -- Basic setup for RL for ikemon go. All state vars are getters and application functions set game variables
  return {
      name = "ikemon-test",
      endpoint = "http://localhost:3000",
      description = "Sample RL config",
      reward_function = reward_function,
      frame_step_interval = 20,
      print_RL_step_summary = true,
      state_variables = {get_p1_life, get_p1_attackMul, get_p2_life, get_p2_attackMul},
      actions = {
        apply_attack_mul_p1 = apply_attack_mul_p1,
        apply_attack_mul_p2 = apply_attack_mul_p2,
      },
      
      hyperparameters = {}
  }