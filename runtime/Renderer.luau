-- Public mount entry. The user's bootstrap code calls Renderer.Mount
-- with a component type (the class table, not an instance) and the
-- Roblox Instance to render under (typically a ScreenGui or a Frame).
--
-- Mount constructs the component, attaches a render handle, and
-- drives the first render. The returned handle can be Unmounted
-- later to clean up — keeps the contract symmetric and lets test
-- harnesses tear things down without leaking signal connections.

local RenderHandle = require(script.Parent.RenderHandle)

local Renderer = {}

function Renderer.Mount(componentType, parentInstance)
	if componentType == nil or componentType.new == nil then
		error("[Blazor] Mount: componentType must be a component class table", 2)
	end
	if typeof(parentInstance) ~= "Instance" then
		error("[Blazor] Mount: parentInstance must be a Roblox Instance", 2)
	end
	local component = componentType.new()
	local handle = RenderHandle.new(parentInstance)
	component:_attachHandle(handle)
	component:_render(true)
	return handle
end

return Renderer
