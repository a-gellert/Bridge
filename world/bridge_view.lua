-- Bridge visuals. Build mode: mirrors the blueprint. Drive mode: follows the simulation and shows stress
-- (green -> yellow -> pulsing red). Also owns the ghost beam and the selected-joint ring.
local spawn = require("world.spawn")
local materials = require("game.config.materials")

local M = {}

local atan2, sqrt = math.atan2, math.sqrt
local beams = {}   -- blueprint beam id -> { go, mat }
local nodes = {}   -- blueprint node id -> { go, anchor }
local ghost = nil  -- { go, mat }
local ring = nil
local t = 0

local DECK_OVERLAP = 0.12 -- decks are a bit longer so joints never show gaps

local function beam_xf(mat, x1, y1, x2, y2)
	local dx, dy = x2 - x1, y2 - y1
	local len = sqrt(dx * dx + dy * dy)
	local m = materials.get(mat)
	local sx = len + (m.drivable and DECK_OVERLAP or 0)
	return (x1 + x2) * 0.5, (y1 + y2) * 0.5, atan2(dy, dx), sx
end

local function place_beam(rec, x1, y1, x2, y2)
	local cx, cy, a, sx = beam_xf(rec.mat, x1, y1, x2, y2)
	spawn.set(materials.get(rec.mat).visual, rec.go, cx, cy, 0, a, sx, 1, 1)
end

-- ------------------------------------------------------------------ build mode
function M.sync(bp)
	-- beams
	for id, rec in pairs(beams) do
		local bm = bp.beams[id]
		if not bm or bm.mat ~= rec.mat then
			spawn.delete(rec.go)
			beams[id] = nil
		end
	end
	for id, bm in pairs(bp.beams) do
		local rec = beams[id]
		if not rec then
			rec = { go = spawn.create(materials.get(bm.mat).visual, 0, 0, 0), mat = bm.mat }
			beams[id] = rec
		end
		local a, b = bp.nodes[bm.a], bp.nodes[bm.b]
		place_beam(rec, a.x, a.y, b.x, b.y)
		spawn.overlay(rec.go, 1, 1, 1, 0)
	end
	-- joints
	for id, rec in pairs(nodes) do
		if not bp.nodes[id] then
			spawn.delete(rec.go)
			nodes[id] = nil
		end
	end
	for id, n in pairs(bp.nodes) do
		local rec = nodes[id]
		if not rec then
			rec = { go = spawn.create(n.anchor and "node_anchor" or "node_joint", n.x, n.y, 0), anchor = n.anchor }
			nodes[id] = rec
		end
		spawn.set(n.anchor and "node_anchor" or "node_joint", rec.go, n.x, n.y, 0, 0)
	end
end

-- Ghost beam + selected joint ring (build mode only).
function M.update_build(dt, session)
	t = t + dt
	local p = session.preview
	if p then
		if ghost and ghost.mat ~= p.mat then
			spawn.delete(ghost.go)
			ghost = nil
		end
		if not ghost then ghost = { go = spawn.create(materials.get(p.mat).visual, 0, 0, 0), mat = p.mat } end
		place_beam(ghost, p.x1, p.y1, p.x2, p.y2)
		local pulse = 0.55 + 0.15 * math.sin(t * 10)
		if p.ok then spawn.overlay(ghost.go, 0.35, 1, 0.45, pulse) else spawn.overlay(ghost.go, 1, 0.25, 0.2, pulse) end
	elseif ghost then
		spawn.delete(ghost.go)
		ghost = nil
	end

	local sel = session.selected_node and session.blueprint.nodes[session.selected_node]
	if sel then
		if not ring then ring = spawn.create("select_ring", 0, 0, 1.55) end
		local s = 1 + 0.12 * math.sin(t * 6)
		spawn.set("select_ring", ring, sel.x, sel.y, 1.55, 0, s, s, 1)
		spawn.tint(ring, 1, 0.88, 0.3, 1)
	elseif ring then
		spawn.delete(ring)
		ring = nil
	end
end

function M.clear_build_helpers()
	if ghost then spawn.delete(ghost.go) ghost = nil end
	if ring then spawn.delete(ring) ring = nil end
end

-- ------------------------------------------------------------------ drive mode
local function stress_color(s)
	if s < 0.5 then
		local k = s / 0.5
		return 0.25 + 0.75 * k, 0.9, 0.3, 0.12 + 0.25 * k
	elseif s < 0.8 then
		local k = (s - 0.5) / 0.3
		return 1, 0.9 - 0.5 * k, 0.15, 0.4 + 0.2 * k
	end
	local pulse = 0.5 + 0.5 * math.sin(t * 22)
	return 1, 0.15, 0.1, 0.6 + 0.3 * pulse
end

function M.update_drive(dt, run)
	t = t + dt
	local x, y = run.sim.x, run.sim.y
	for id, rec in pairs(beams) do
		local c = run.beam_of[id]
		if c then
			if c.broken then
				spawn.delete(rec.go)
				beams[id] = nil
			else
				place_beam(rec, x[c.a], y[c.a], x[c.b], y[c.b])
				local r, g, b, a = stress_color(c.stress)
				spawn.overlay(rec.go, r, g, b, a)
			end
		end
	end
	for id, rec in pairs(nodes) do
		local p = run.particle_of[id]
		if p and not rec.anchor then
			go.set_position(vmath.vector3(x[p], y[p], 0), rec.go)
		end
	end
end

function M.destroy()
	for id, rec in pairs(beams) do spawn.delete(rec.go) beams[id] = nil end
	for id, rec in pairs(nodes) do spawn.delete(rec.go) nodes[id] = nil end
	M.clear_build_helpers()
end

return M
