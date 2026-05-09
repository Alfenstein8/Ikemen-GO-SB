local SBLIB = require("external.mods.sb-lib")

function Start()
  SBLIB.setup_config_from_path("external/mods/config-example")
end


local prev_total_life = nil

function Update(frame)
    local total_life = Player(1).get.life() + Player(2).get.life()

    if prev_total_life ~= nil and total_life ~= prev_total_life then
         -- print(string.format(
         --     "[STEP] Frame=%d | Total Life: %d -> %d",
         --     frame,
         --     prev_total_life,
         --     total_life
         -- ))
        SBLIB.step(frame)
    end

    prev_total_life = total_life
end

function RoundStarted()
  SBLIB.start()
end

function RoundOver()
  SBLIB.done()
end

-- receiveddamage