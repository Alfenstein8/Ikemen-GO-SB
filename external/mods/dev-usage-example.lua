-- The point of this file is to show how a GAME DEVELOPER WOULD USE IT

-- Function that sets up config and sends it to the server
local function setupConfig()
  SBLIB.setup_config("external/mods/config-example")
end
hook.add("launchFight","test", setupConfig);


-- Function that runs every frame and serves sb-lib with game_state variables this runs every frame Interval
-- See config for frame interval
local frame = 0
local function stepWithGameState()
  frame = frame + 1
  setLevels(1,8)
  -- Run step which mutates the game state with activations from server
  SBLIB.step(frame)
end
hook.add("loop#watch","state", stepWithGameState);

-- setGameSpeed(10000)