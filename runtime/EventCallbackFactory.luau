-- Factory that mints EventCallback instances. The runtime shape of
-- a "callback" is `{ _invoke = function }` — Elements.luau handles
-- that table (or a raw function) indifferently when wiring up
-- signal connections.
--
-- We bind the `receiver` into the closure here because the
-- transpiler lowers `EventCallback.Factory.Create(this, OnClick)`
-- to `EventCallback.Factory:Create(self, self.OnClick)` — and
-- `self.OnClick` is a raw method-table lookup, not a bound
-- delegate. Without binding, the connected signal would call
-- `OnClick(<roblox-args>)` and `self` would be nil inside the
-- method. Binding receiver as the first arg is exactly what Lua's
-- `obj:Method(...)` ↔ `Method(obj, ...)` equivalence needs.

local EventCallbackFactory = {}
EventCallbackFactory.__index = EventCallbackFactory

setmetatable(EventCallbackFactory, {
	__tostring = function() return "EventCallbackFactory" end,
})

function EventCallbackFactory.new(...)
	local self = setmetatable({}, EventCallbackFactory)
	return self:constructor(...) or self
end

EventCallbackFactory.__ctorParams = {}
EventCallbackFactory.__interfaces = {}

function EventCallbackFactory:constructor()
end

function EventCallbackFactory:Create(receiver, callback)
	return {
		_invoke = function(...)
			return callback(receiver, ...)
		end,
	}
end

return EventCallbackFactory
