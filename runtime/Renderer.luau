-- Public mount entry. The user's bootstrap code calls Renderer.Mount
-- with a component type (the class table, not an instance), the
-- Roblox Instance to render under (typically a ScreenGui or a Frame),
-- and an IInstantiator (auto-bound by the DI Container, so callers
-- ctor-inject it and pass through).
--
-- Mount constructs the component via the instantiator so its ctor
-- params get resolved, attaches a render handle, and drives the
-- first render. The returned handle can be Unmounted later to clean
-- up — keeps the contract symmetric and lets test harnesses tear
-- things down without leaking signal connections.

local RenderHandle = require(script.Parent.RenderHandle)

local Renderer = {}

function Renderer.Mount(componentType, parentInstance, instantiator)
	if componentType == nil or componentType.new == nil then
		error("[Blazor] Mount: componentType must be a component class table", 2)
	end
	if typeof(parentInstance) ~= "Instance" then
		error("[Blazor] Mount: parentInstance must be a Roblox Instance", 2)
	end
	if instantiator == nil or instantiator.Instantiate == nil then
		error("[Blazor] Mount: instantiator must implement IInstantiator (with an Instantiate method)", 2)
	end
	local component = instantiator:Instantiate(componentType)
	local handle = RenderHandle.new(parentInstance, instantiator)
	component:_attachHandle(handle)
	component:_render(true)
	return handle
end

return Renderer
