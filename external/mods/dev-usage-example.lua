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

 -- If the match is over. Reload the game. Infinite matches for training! 
  if matchover() then
    matchReload()
  end

end
hook.add("loop#watch","state", stepWithGameState);

setGameSpeed(100)

-- If you wanna run stuff from menu use this!
-- local function menuPrint()
--   print("Working menu init print")
-- end
-- hook.add("main.menu.loop", "myTestHook", menuPrint)

-- Relevant and interesting hooks that could be used
-- matchReload() refreshes match 
-- roundStart() idk?

