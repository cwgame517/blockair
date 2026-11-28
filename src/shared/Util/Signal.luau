--!strict
-- 아주 작은 신호(이벤트) 도구. 서비스끼리 "레벨이 올랐다" 같은 소식을 주고받을 때 쓴다.
local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (self: Connection) -> () }

function Signal.new()
	return setmetatable({ _handlers = {} :: { [number]: (...any) -> () }, _nextId = 0 }, Signal)
end

function Signal:Connect(fn: (...any) -> ())
	self._nextId += 1
	local id = self._nextId
	self._handlers[id] = fn
	local handlers = self._handlers
	return {
		Disconnect = function()
			handlers[id] = nil
		end,
	}
end

function Signal:Fire(...: any)
	for _, fn in self._handlers do
		task.spawn(fn, ...)
	end
end

return Signal
