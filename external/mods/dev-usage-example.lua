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
  -- Run step which mutates the game state with activations from server
  SBLIB.step(frame)

 -- If the match is over. Reload the game. Infinite matches for training! 
  if matchover() then
    matchReload()
  end
end
hook.add("loop#watch","state", stepWithGameState);
setGameSpeed(1000)