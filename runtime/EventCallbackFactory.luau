-- Factory that mints EventCallback instances. The runtime shape of
-- a "callback" is `{ _invoke = function, InvokeAsync = method }` —
-- Elements.luau handles that table (or a raw function) indifferently
-- when wiring up signal connections, and child components invoke
-- EventCallback parameters via `callback:InvokeAsync(arg)` (the
-- method-call form the transpiler emits for the stub's InvokeAsync).
--
-- We bind the `receiver` into the closure here because the
-- transpiler lowers `EventCallback.Factory.Create(this, OnClick)`
-- to `EventCallback.Factory:Create(self, self.OnClick)` — and
-- `self.OnClick` is a raw method-table lookup, not a bound
-- delegate. Without binding, the connected signal would call
-- `OnClick(<roblox-args>)` and `self` would be nil inside the
-- method. Binding receiver as the first arg is exactly what Lua's
-- `obj:Method(...)` ↔ `Method(obj, ...)` equivalence needs.
--
-- Created callbacks are cached per (receiver, callback) so the same
-- handler wired on consecutive renders returns the *same* table.
-- The reconciler reuses signal connections only on referential
-- equality of the attribute value; without the cache every re-render
-- would mint a fresh table and disconnect/reconnect every handler.
-- Weak keys on both levels so unmounted components (and their
-- method closures) don't get pinned by the factory.

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
	self._cache = setmetatable({}, { __mode = "k" })
end

local function mint(receiver, callback)
	local eventCallback = {
		_invoke = function(...)
			return callback(receiver, ...)
		end,
	}
	-- Stub signature returns void — swallow the handler's return value.
	function eventCallback:InvokeAsync(...)
		self._invoke(...)
	end
	return eventCallback
end

function EventCallbackFactory:Create(receiver, callback)
	if receiver == nil then
		-- No cache key to hang off; mint uncached (static handlers).
		return mint(receiver, callback)
	end

	local perReceiver = self._cache[receiver]
	if perReceiver == nil then
		perReceiver = setmetatable({}, { __mode = "k" })
		self._cache[receiver] = perReceiver
	end

	local existing = perReceiver[callback]
	if existing == nil then
		existing = mint(receiver, callback)
		perReceiver[callback] = existing
	end
	return existing
end

return EventCallbackFactory
