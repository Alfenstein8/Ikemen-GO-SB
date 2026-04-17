-- The point of this file is to show how a GAME DEVELOPER WOULD USE IT
-- Function that sets up config and sends it to the server
 local function setupConfig()
    if SBLIB then SBLIB.setup_config("external/mods/config-example") end
 end
 hook.add("main.menu.loop", "setupConfigOnce", setupConfig)


-- Function that runs every frame and serves sb-lib with game_state variables this runs every frame Interval
-- See config for frame interval
local frame = 0
local function stepWithGameState()
  frame = frame + 1

  -- If the match is over. Reload the game. Infinite matches for training!
  if matchover() then
    matchReload()
    SBLIB.done()
  end
  
  -- Run step which mutates the game state with activations from server
  if roundstate() == 2 then
    SBLIB.step(frame)
    setLevels(1,8)
  end
end
hook.add("loop#watch","state", stepWithGameState);

setGameSpeed(10000)

addHotkey('o', true, false, false, true, false, 'setGameSpeed(100000)')
addHotkey('p', true, false, false, true, false, 'setGameSpeed(1)')
-- Relevant values for when animation run in game (Round state like at the start)
-- roundstate() values:
-- 0 = pre-intro
-- 1 = intro playing
-- 2 = fight active (this is where the fight begins after animations)
