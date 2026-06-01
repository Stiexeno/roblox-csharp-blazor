-- Frame-list → Instance-tree projector.
--
-- v1 strategy: tear down the existing tree and rebuild from scratch
-- on every render. Correct, simple to reason about, easy to verify
-- by inspection. Positional diffing (the real Blazor algorithm) is
-- planned for v1.1 once we have a real workload to tune against;
-- the public API doesn't change when we swap implementations.
--
-- The reconciler walks frames as a stack:
--   element/component frame → push, becomes the current parent
--   attribute frame         → applied to top of stack
--   content frame           → applied to top of stack
--   end frame               → pop
--
-- Component frames don't produce an Instance directly. We collect
-- their parameters into a "sink" table while their region is open,
-- then on close hand the component + parameters + current parent
-- Instance to `mountChild` — a callback the caller (RenderHandle)
-- supplies. That callback owns the act of creating a RenderHandle
-- for the child and driving its first render, which is what lets
-- Reconciler stay free of any static dependency on RenderHandle
-- (they'd otherwise import each other).

local Elements = require(script.Parent.Elements)

local Reconciler = {}

-- Applies a flat frame list under `rootInstance`. `mountChild` is
-- invoked once per child component on its CloseComponent frame,
-- with (component, parentInstance, parameters). Returns the
-- teardown list (event disconnects) so the caller can wipe them
-- before the next render.
function Reconciler.Apply(rootInstance, frames, mountChild)
	-- Stack of currently-open render targets. Either a Roblox Instance
	-- (element open) or a `{ _kind = "componentSink", ... }` table
	-- (component open). The root Instance is at the bottom and is
	-- never popped — frame end-markers only pop entries we pushed.
	local stack = { rootInstance }
	local teardowns = {}

	for _, frame in ipairs(frames) do
		local kind = frame.kind
		local top = stack[#stack]

		if kind == "element" then
			local instance = Elements.Create(frame.name)
			instance.Parent = top
			table.insert(stack, instance)

		elseif kind == "component" then
			-- Component sink. Parameters accumulate here; mount fires
			-- on the matching CloseComponent so OnInitialized /
			-- BuildRenderTree see the full parameter set in one shot,
			-- matching Blazor's per-render parameter pass.
			table.insert(stack, {
				_kind = "componentSink",
				_componentType = frame.componentType,
				_parameters = {},
			})

		elseif kind == "attribute" then
			if type(top) == "table" and top._kind == "componentSink" then
				top._parameters[frame.name] = frame.value
			else
				local teardown = Elements.ApplyAttribute(top, frame.name, frame.value)
				if teardown then table.insert(teardowns, teardown) end
			end

		elseif kind == "content" then
			if type(top) == "table" and top._kind == "componentSink" then
				-- Razor lowers `<MyComp>text</MyComp>` to a ChildContent
				-- attribute, but hand-written component trees might emit
				-- raw content frames into a component region. Coalesce
				-- both into the ChildContent parameter so the child
				-- component sees one canonical source of inner content.
				top._parameters.ChildContent = frame.content
			else
				Elements.ApplyContent(top, frame.content)
			end

		elseif kind == "end" then
			local popped = table.remove(stack)
			if type(popped) == "table" and popped._kind == "componentSink" then
				-- Parent Instance is whatever's now on top of the
				-- stack — the element/component above this child.
				local parent = stack[#stack]
				mountChild(popped._componentType, parent, popped._parameters)
			end
		end
	end

	return teardowns
end

-- Tears down a previously-applied tree. Disconnects every captured
-- event subscription and Destroys every child of root. The next
-- Apply rebuilds from scratch.
function Reconciler.Teardown(rootInstance, teardowns)
	for _, disconnect in ipairs(teardowns) do
		disconnect()
	end
	for _, child in ipairs(rootInstance:GetChildren()) do
		child:Destroy()
	end
end

return Reconciler
