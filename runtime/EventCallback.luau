-- EventCallback is mostly a name in user code: `EventCallback.Factory.Create(...)`
-- is what they actually call, which routes through the singleton Factory
-- field below. The wrapped callback table (returned by Factory:Create)
-- is plain data, so we don't expose a class metatable for it.

local EventCallbackFactory = require(script.Parent.EventCallbackFactory)

local EventCallback = {}

-- Singleton, mirroring `EventCallback.Factory` in Blazor. One factory
-- is enough; it carries no state and constructing it on every Create
-- call would just churn garbage.
EventCallback.Factory = EventCallbackFactory.new()

return EventCallback
