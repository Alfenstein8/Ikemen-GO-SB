local SBLIB = require("external.mods.sb-lib")

function Start()
  SBLIB.setup_config_from_path("external/mods/config-example")
end

function Update(frame)
  SBLIB.step(frame)
end

function RoundStarted()
  SBLIB.start()
end

function RoundOver()
  SBLIB.done()
end
