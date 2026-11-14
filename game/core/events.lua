-- Tiny event bus with one queue per subscriber.
-- Scripts never call into each other: a GUI script must not run gui.* code from a game object script's
-- update. Instead every script drains its own queue in its own update/on_input.
local M = {}

local queues = {}

-- Create (or reset) the queue for a subscriber name, e.g. "gui" or "world".
function M.subscribe(name)
	queues[name] = {}
end

function M.unsubscribe(name)
	queues[name] = nil
end

function M.emit(id, data)
	for _, q in pairs(queues) do
		q[#q + 1] = { id = id, data = data or {} }
	end
end

-- Returns the pending events of a subscriber and clears its queue.
function M.drain(name)
	local q = queues[name]
	if not q or #q == 0 then return nil end
	queues[name] = {}
	return q
end

return M
