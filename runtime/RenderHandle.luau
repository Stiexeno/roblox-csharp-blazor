-- Per-component bookkeeping for the reconciler. Holds the parent
-- Instance the component renders under, the IInstantiator used to
-- construct child components, and the previously-reconciled tree so
-- the next render can diff against it instead of tearing everything
-- down.
--
-- Components don't talk to the Reconciler directly — they hand frames
-- to their RenderHandle, which calls into the Reconciler. That extra
-- hop is what lets a child component re-render in isolation (its
-- handle scopes the diff to its own subtree) and lets the instantiator
-- propagate to children without each component having to know about DI.
--
-- Child components are mounted via the `mountChild` callback the
-- reconciler invokes when it discovers a component frame. The returned
-- RenderHandle is stored on the tree node; on subsequent renders, if
-- the child component's position survives (same componentType at the
-- same tree position), `refreshChild` is invoked with the new parameter
-- set and the child re-renders its own subtree. That's how state
-- locality works: each component owns its own tree, and a parent
-- re-render forwards parameters down rather than wiping the whole
-- subtree.

local Reconciler = require(script.Parent.Reconciler)

local RenderHandle = {}
RenderHandle.__index = RenderHandle

setmetatable(RenderHandle, {
	__tostring = function() return "RenderHandle" end,
})

function RenderHandle.new(parentInstance, instantiator)
	local self = setmetatable({}, RenderHandle)
	self._parent = parentInstance
	self._instantiator = instantiator
	self._tree = nil  -- populated by Reconciler.Reconcile on first Apply
	return self
end

-- Closure factory: produces a mountChild callable bound to the
-- instantiator so the Reconciler can construct child components with
-- their ctor params DI-resolved without itself depending on any DI
-- type. The returned RenderHandle is what the reconciler stores on the
-- child's tree node — that handle is what gets re-used on the next
-- diff pass.
local function makeMountChild(instantiator)
	return function(componentType, parentInstance, parameters)
		local component = instantiator:Instantiate(componentType)
		for name, value in pairs(parameters) do
			rawset(component, name, value)
		end
		local childHandle = RenderHandle.new(parentInstance, instantiator)
		childHandle._component = component
		component:_attachHandle(childHandle)
		component:_render(true)
		return childHandle
	end
end

-- Forwards a new parameter set to a child component that survived
-- the diff pass and triggers its re-render. Direct rawset bypasses any
-- user-defined __newindex on the component's class table (compiler-
-- emitted accessors are plain field writes in Luau, so rawset is
-- semantically equivalent and avoids surprises from custom metatables).
local function refreshChild(childHandle, parameters)
	local component = childHandle._component
	for name, value in pairs(parameters) do
		rawset(component, name, value)
	end
	component:_render(false)
end

function RenderHandle:Apply(frames)
	if self._unmounted then return end
	self._tree = Reconciler.Reconcile(
		self._tree,
		frames,
		self._parent,
		makeMountChild(self._instantiator),
		refreshChild)
end

-- Tears down the rendered tree without re-applying. Called when the
-- component is removed by its parent (or by Unmount at the root).
-- Detaches the component's handle so a StateHasChanged after unmount
-- is a no-op instead of rebuilding the tree under a possibly-destroyed
-- parent; the _unmounted flag backstops any direct Apply call.
function RenderHandle:Unmount()
	if self._unmounted then return end
	self._unmounted = true
	Reconciler.Teardown(self._tree, self._parent)
	self._tree = nil
	if self._component then
		self._component._renderHandle = nil
		self._component = nil
	end
end

return RenderHandle
