-- Per-component bookkeeping for the reconciler. Holds the parent
-- Instance the component renders under, plus the teardown list from
-- the previous render so re-renders can clean up before rebuilding.
--
-- Components don't talk to the Reconciler directly — they hand frames
-- to their RenderHandle, which calls into the Reconciler. That extra
-- hop is what lets a child component re-render in isolation (its
-- handle scopes the teardown/rebuild to its own parent Instance).
--
-- RenderHandle also owns the "mount child component" closure passed
-- into Reconciler.Apply. Keeping that here means Reconciler doesn't
-- need to know how RenderHandles are constructed — it just calls the
-- closure when a CloseComponent frame fires.

local Reconciler = require(script.Parent.Reconciler)

local RenderHandle = {}
RenderHandle.__index = RenderHandle

setmetatable(RenderHandle, {
	__tostring = function() return "RenderHandle" end,
})

function RenderHandle.new(parentInstance)
	local self = setmetatable({}, RenderHandle)
	self._parent = parentInstance
	self._teardowns = {}
	return self
end

local function mountChild(componentType, parentInstance, parameters)
	local component = componentType.new()
	-- Parameters land as fields on the component. Direct rawset
	-- bypasses any user-defined __newindex that might exist on the
	-- component's class table (compiler-emitted accessors are plain
	-- field writes in Luau, so rawset is semantically equivalent and
	-- avoids surprises from custom metatables down the line).
	for name, value in pairs(parameters) do
		rawset(component, name, value)
	end
	local childHandle = RenderHandle.new(parentInstance)
	component:_attachHandle(childHandle)
	component:_render(true)
end

function RenderHandle:Apply(frames)
	Reconciler.Teardown(self._parent, self._teardowns)
	self._teardowns = Reconciler.Apply(self._parent, frames, mountChild)
end

-- Tears down the rendered tree without re-applying. Called when the
-- component is removed by its parent (or by Unmount at the root).
function RenderHandle:Unmount()
	Reconciler.Teardown(self._parent, self._teardowns)
	self._teardowns = {}
end

return RenderHandle
