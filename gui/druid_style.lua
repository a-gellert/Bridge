-- Druid style: squash on press, punch on release, gentle hover grow on desktop, shake when disabled.
local settings = require("druid.system.settings")

local M = {}
local V3 = vmath.vector3

local function scaled(base, k)
	return V3(base.x * k, base.y * k, base.z)
end

M["button"] = {
	LONGTAP_TIME = 0.4,
	AUTOHOLD_TRIGGER = 0.8,
	DOUBLETAP_TIME = 0.4,
	BTN_SOUND = "click",
	BTN_SOUND_DISABLED = "error",

	on_init = function(self) end,

	on_hover = function(self, node, state)
		local target = state and scaled(self.start_scale, 0.92) or self.start_scale
		gui.animate(node, gui.PROP_SCALE, target, state and gui.EASING_OUTQUAD or gui.EASING_OUTBACK, state and 0.06 or 0.18)
	end,

	on_mouse_hover = function(self, node, state)
		if self.hover:is_hovered() then return end
		local target = state and scaled(self.start_scale, 1.05) or self.start_scale
		gui.animate(node, gui.PROP_SCALE, target, gui.EASING_OUTSINE, 0.1)
	end,

	on_click = function(self, node)
		gui.set_scale(node, scaled(self.start_scale, 1.08))
		gui.animate(node, gui.PROP_SCALE, self.start_scale, gui.EASING_OUTBACK, 0.22)
		if not self.silent then settings.play_sound(M.button.BTN_SOUND) end
	end,

	on_click_disabled = function(self, node)
		settings.play_sound(M.button.BTN_SOUND_DISABLED)
		local p = self.start_pos
		gui.animate(node, "position.x", p.x - 6, gui.EASING_OUTSINE, 0.04, 0, function()
			gui.animate(node, "position.x", p.x + 6, gui.EASING_OUTSINE, 0.08, 0, function()
				gui.animate(node, "position.x", p.x, gui.EASING_OUTSINE, 0.04)
			end)
		end)
	end,

	on_set_enabled = function(self, node, state)
		local c = gui.get_color(node)
		c.w = state and 1 or 0.45
		gui.set_color(node, c)
	end,
}

return M
