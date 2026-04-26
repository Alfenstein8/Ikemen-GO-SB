hook.add("main.menu.loop", "setupConfigOnce", function() Start() end)
local frame = 0
local running = false

local function setLevels(p1, p2)
  if player(1) then
    setAILevel(p1)
  end
  if player(2) then
    setAILevel(p2)
  end
end

local function set_random_cpu_levels()
  -- generates random number between 1 and 8
  local rand1 = math.random(1, 8)
  local rand2 = math.random(1, 8)
  setLevels(rand1, rand2)
end

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
    RoundOver()
    running = false
  end

  -- Match started
  if roundstart() then
    print("Round started!")
    RoundStarted()
    running = true
  end

  -- Run step which mutates the game state with activations from server
  if roundstate() == 2 then
    Update(frame)
  end
end
hook.add("loop#watch", "state", stepWithGameState);

addHotkey('o', true, false, false, true, false, 'setGameSpeed(100000)')
addHotkey('p', true, false, false, true, false, 'setGameSpeed(1)')
addHotkey('l', true, false, false, true, false, 'setGameSpeed(10)')
-- Relevant values for when animation run in game (Round state like at the start)
-- roundstate() values:
-- 0 = pre-intro
-- 1 = intro playing
-- 2 = fight active (this is where the fight begins after animations)

---- Utils ----
Utils = {}
function Utils.round(num, decimals)
  local mult = 10 ^ (decimals or 0)
  return math.floor(num * mult + 0.5) / mult
end

function Utils.PrintAllGetters()
  for n = 1, 2 do
    local p = Player(n)
    print("=== Player " .. n .. " ===")
    for name, fn in pairs(p.get) do
      print(name .. ": " .. tostring(fn()))
    end
  end
end

function Player(n)
  player(n)
  local p = {}
  local get = {
    life           = life,
    redlife        = redlife,
    combocount     = combocount,
    hitfall        = hitfall,
    decisiveround  = decisiveround,
    attack         = attack,
    attackmul      = attackmul,
    dizzypoints    = dizzypoints,
    dizzypointsmax = dizzypointsmax,
    fighttime      = fighttime,
    defence        = defence,
    defencemul     = defencemul,
    receiveddamage = receiveddamage,
    receivedhits   = receivedhits,
    hitcount       = hitcount,
    roundsexisted  = roundsexisted,
    roundswon      = roundswon,
    roundno        = roundno,
    power          = power,
    powermax       = powermax,
    score          = score,
    scoretotal     = scoretotal,
    timeremaining  = timeremaining,
    timeelapsed    = timeelapsed,
    movecountered  = movecountered,
  }
  local set = {
    attackmul = attackmul,
  }

  p.get = get
  p.set = set
  return p
end
