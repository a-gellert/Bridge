local mock = require("defold_mock")
local ROOT = package.path:match("^(.-)/%?%.lua")
mock.read_factories(ROOT .. "/world/world.go")

local levels = require("game.levels.levels")
local level_view = require("world.level_view")

-- Test Valley Level 1
local lvl1 = levels.get(1)
local v1 = level_view.build(lvl1)
assert(#v1.clouds >= 14, "expected at least 14 clouds, got " .. #v1.clouds)
assert(#v1.fauna >= 10, "expected rich fauna, got " .. #v1.fauna)

local c0_x = v1.clouds[1].x
local speed = v1.clouds[1].speed
print("Cloud 1 start x: " .. string.format("%.2f", c0_x) .. ", speed: " .. string.format("%.2f", speed) .. " m/s")

for _ = 1, 120 do
	level_view.update(1 / 60)
end

local c2_x = v1.clouds[1].x
local delta = c2_x - c0_x
print("Cloud 1 after 2s x: " .. string.format("%.2f", c2_x) .. ", moved: " .. string.format("%.2f", delta) .. " m")
assert(math.abs(delta - speed * 2) < 0.2, "cloud should move steadily at its assigned speed")

-- Test Lab Level 81
local lvl81 = levels.get(81)
local v81 = level_view.build(lvl81)
local drones = 0
for _, f in ipairs(v81.fauna) do
	if f.kind == "lab_drone" then drones = drones + 1 end
end
print("Lab drones count: " .. drones)
assert(drones >= 3, "expected survey drones in lab theme")

-- Test Canyon Level 41
local lvl41 = levels.get(41)
local v41 = level_view.build(lvl41)
local eagles = 0
for _, f in ipairs(v41.fauna) do
	if f.kind == "eagle" then eagles = eagles + 1 end
end
print("Canyon soaring raptors count: " .. eagles)
assert(eagles >= 1, "expected soaring eagles in canyon")

-- Run 600 frames (10 seconds) to test jumping fish transitions and full cloud flight
for _ = 1, 600 do
	level_view.update(1 / 60)
end
print("Fish jump cycle & 10s simulation passed with zero errors!")

print("All cloud & fauna tests PASSED!")
