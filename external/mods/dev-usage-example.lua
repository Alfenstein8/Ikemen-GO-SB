-- The point of this file is to show how a GAME DEVELOPER WOULD USE IT
-- Function that sets up config and sends it to the server
 local function setupConfig()
    if SBLIB then SBLIB.setup_config("external/mods/config-example") end
 end
 hook.add("main.menu.loop", "setupConfigOnce", setupConfig)


-- Function that runs every frame and serves sb-lib with game_state variables this runs every frame Interval
-- See config for frame interval
local frame = 0
local running = false
local function stepWithGameState()
  frame = frame + 1


  -- If match is started during first round. Then set random cpu lvl
  if roundno() == 1 and roundstart() then
    set_random_cpu_levels()
  end

  -- If the match is over. Reload the game. Infinite matches for training!
  if matchover() and running then
    matchReload()
    print("Match over")
  end

  -- Round over
  if (roundover() or matchover()) and running then
    print("Round over!")
    SBLIB.done()
    running = false
  end

  -- Match started
  if roundstart() then
    print("Round started!")
    SBLIB.start()
    running = true
  end

  -- Run step which mutates the game state with activations from server
  if roundstate() == 2 then
    SBLIB.step(frame)
  end
end
hook.add("loop#watch","state", stepWithGameState);

function set_random_cpu_levels()
  -- generates random number between 1 and 8
  local rand1 = math.random(0,8)
  local rand2 = math.random(0,8)
  setLevels(rand1, rand2)
end

setGameSpeed(10000)

addHotkey('o', true, false, false, true, false, 'setGameSpeed(100000)')
addHotkey('p', true, false, false, true, false, 'setGameSpeed(1)')
addHotkey('l', true, false, false, true, false, 'setGameSpeed(10)')
-- Relevant values for when animation run in game (Round state like at the start)
-- roundstate() values:
-- 0 = pre-intro
-- 1 = intro playing
-- 2 = fight active (this is where the fight begins after animations)
