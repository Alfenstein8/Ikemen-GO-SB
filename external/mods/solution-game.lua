local SBLIB = require("external.mods.sb-lib")
local function players_hit_each_other()

  local p1_life = Player(1).get.life()
  local p2_life = Player(2).get.life()

  if last_p1_life == nil then
    last_p1_life = p1_life
    last_p2_life = p2_life
    return false
  end

  local changed = p1_life ~= last_p1_life or p2_life ~= last_p2_life

  last_p1_life = p1_life
  last_p2_life = p2_life

  return changed
end

function Start()
  SBLIB.setup_config_from_path("external/mods/config-example")
end

function Update(frame)
  if players_hit_each_other() then
    SBLIB.step(frame)
  end
end

function RoundStarted()
  SBLIB.start()
end

function RoundOver()
  SBLIB.done()
end
