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
  setLevels(8, 1)
end

local function stepWithGameState()
  frame = frame + 1


  -- If match is started during first round. Then set random cpu lvl
  if roundno() == 1 and roundstart() then
    local val = math.random()
    print("randval", val)
    if val > 0.5 then
      setLevels(1,8)
    end
    if val < 0.5 then
      setLevels(8,1)
    end
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

local function fn(n, fn, has_param)
  if has_param then
    return function(param)
      player(n)
      return fn(param)
    end
  end
  return function()
    player(n)
    return fn()
  end
end
function Player(n)
  local p = {}
  local get = {
    life           = fn(n, life),
    redlife        = fn(n, redlife),
    combocount     = fn(n, combocount),
    hitfall        = fn(n, hitfall),
    decisiveround  = fn(n, decisiveround),
    attack         = fn(n, attack),
    attackmul      = fn(n, attackmul),
    dizzypoints    = fn(n, dizzypoints),
    dizzypointsmax = fn(n, dizzypointsmax),
    fighttime      = fn(n, fighttime),
    defence        = fn(n, defence),
    defencemul     = fn(n, defencemul),
    receiveddamage = fn(n, receiveddamage),
    receivedhits   = fn(n, receivedhits),
    hitcount       = fn(n, hitcount),
    roundsexisted  = fn(n, roundsexisted),
    roundswon      = fn(n, roundswon),
    roundno        = fn(n, roundno),
    power          = fn(n, power),
    powermax       = fn(n, powermax),
    score          = fn(n, score),
    scoretotal     = fn(n, scoretotal),
    timeremaining  = fn(n, timeremaining),
    timeelapsed    = fn(n, timeelapsed),
    movecountered  = fn(n, movecountered),
    posx = fn(n,posX),
    posy = fn(n,posY),
    guardpoints  = fn(n, guardpoints),
  }
  local set = {
    attackmul = fn(n, setAttackMul, true),
    dizzypoints = fn(n, setDizzyPoints, true),
    guardpoints = fn(n, setGuardPoints, true),
    life = fn(n, setLife, true),
    power = fn(n, setPower, true),
  }

  p.get = get
  p.set = set
  return p
end
