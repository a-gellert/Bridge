-- Dumps existing levels of a chapter to JSON
local function serialize(v)
	local t = type(v)
	if t == "number" or t == "boolean" then return tostring(v)
	elseif t == "string" then return string.format("%q", v)
	elseif t == "table" then
		local is_arr = (#v > 0)
		local parts = {}
		if is_arr then
			for _, item in ipairs(v) do parts[#parts + 1] = serialize(item) end
			return "[" .. table.concat(parts, ", ") .. "]"
		else
			for k, val in pairs(v) do parts[#parts + 1] = string.format("%q: %s", tostring(k), serialize(val)) end
			return "{" .. table.concat(parts, ", ") .. "}"
		end
	end
	return "null"
end

local ch1 = require("game.levels.chapter1")
local ch2 = require("game.levels.chapter2")
local ch3 = require("game.levels.chapter3")
local ch4 = require("game.levels.chapter4")

writefile("chapter1_dump.json", serialize(ch1.levels))
writefile("chapter2_dump.json", serialize(ch2.levels))
writefile("chapter3_dump.json", serialize(ch3.levels))
writefile("chapter4_dump.json", serialize(ch4.levels))
print("Dumped existing chapters successfully!")
