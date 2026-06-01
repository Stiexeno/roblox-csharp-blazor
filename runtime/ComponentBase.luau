-- Base class for user components. Mirrors Blazor's ComponentBase:
-- override BuildRenderTree to describe UI, call StateHasChanged when
-- state changes, hook OnInitialized / OnParametersSet / OnAfterRender
-- for lifecycle.
--
-- The class scaffold (Component.new / :constructor / __ctorParams /
-- __interfaces) matches the shape the compiler emits for user
-- classes, so derived components compiled from C# integrate without
-- any special-casing.

local RenderTreeBuilder = require(script.Parent.RenderTreeBuilder)

local Component = {}
Component.__index = Component

setmetatable(Component, {
	__tostring = function() return "Component" end,
})

function Component.new(...)
	local self = setmetatable({}, Component)
	return self:constructor(...) or self
end

-- Empty by default. Derived components that need DI get their own
-- __ctorParams emitted by the compiler.
Component.__ctorParams = {}
Component.__interfaces = { "IComponent" }

function Component:constructor()
	self._renderHandle = nil   -- attached by the reconciler at mount
	self._initialized = false
	self._isRendering = false  -- guards against StateHasChanged inside Build
end

-- The reconciler hands a handle to the component once it's mounted.
-- Pre-mount StateHasChanged calls are no-ops (first render hasn't
-- happened yet — any state set in constructor or OnInitialized will
-- be reflected when it does).
function Component:_attachHandle(handle)
	self._renderHandle = handle
end

-- Lifecycle hooks. Default no-ops; user components override.
function Component:OnInitialized() end
function Component:OnParametersSet() end
function Component:OnAfterRender(firstRender) end

-- The override point for generated/user code. Razor's BuildRenderTree
-- maps to this method; hand-written components do the same.
function Component:BuildRenderTree(builder)
end

-- Schedules a re-render. We don't batch yet — each call re-renders
-- synchronously. That keeps the model predictable for v1 (no "why
-- isn't my UI updated yet?" surprises); batching can come later
-- once we have a perf signal that justifies the added complexity.
function Component:StateHasChanged()
	if self._renderHandle == nil then return end
	if self._isRendering then
		-- A StateHasChanged inside BuildRenderTree would recurse
		-- infinitely. Match Blazor's behavior: ignore, the in-flight
		-- render already reflects current state.
		return
	end
	self:_render(false)
end

-- Internal: drive one render cycle. Called once by the reconciler
-- at mount (firstRender = true), and by StateHasChanged thereafter.
function Component:_render(firstRender)
	if not self._initialized then
		self:OnInitialized()
		self._initialized = true
	end
	self:OnParametersSet()

	self._isRendering = true
	local builder = RenderTreeBuilder.new()
	local ok, err = pcall(function()
		self:BuildRenderTree(builder)
	end)
	self._isRendering = false

	if not ok then
		error(string.format(
			"[Blazor] BuildRenderTree failed for %s: %s",
			tostring(getmetatable(self)), tostring(err)), 0)
	end

	self._renderHandle:Apply(builder:GetFrames())
	self:OnAfterRender(firstRender)
end

return Component
