-- Stunt combo math: chain window, multiplier and the per-run cash cap.
local stunts = require("game.core.stunts")

local s = stunts.new()
local gain, mult = stunts.add(s, "boost", 20)
assert(gain == 20 and mult == 1, "first stunt is x1")
gain, mult = stunts.add(s, "air", 40)
assert(gain == 54, "second stunt gets x1.35, got " .. gain)
assert(mult > 1.3 and mult < 1.4, "multiplier after two stunts")
assert(s.score == 74, "score accumulates")
assert(s.combo == 2 and s.max_combo == 2, "combo count")
assert(s.cash == 7, "cash is score / 10, got " .. s.cash)

-- The window keeps the chain alive, then drops it back to x1.
stunts.tick(s, stunts.WINDOW - 0.1)
assert(s.combo == 2, "combo survives inside the window")
stunts.tick(s, 0.2)
assert(s.combo == 0, "combo expires")
gain = stunts.add(s, "portal", 70)
assert(gain == 70, "expired combo starts from x1 again")

-- Multiplier is capped and cash never exceeds the per-run cap.
local long = stunts.new()
for _ = 1, 30 do stunts.add(long, "boost", 100) end
assert(stunts.multiplier(long) == stunts.MAX_MULT, "multiplier cap")
assert(long.cash == stunts.MAX_CASH, "cash cap")
