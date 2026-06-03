-- Frame-list → Instance-tree reconciler with positional diffing.
--
-- The reconciler converts a flat frame list (the output of a render
-- pass) into a tree of "nodes" — each node owns either a Roblox
-- Instance (element nodes), a child component's RenderHandle
-- (component nodes), or a chunk of text content (content nodes).
-- On the next render, the previous tree is diffed against the new
-- tree by walking child arrays in parallel and matching by shape
-- (kind + element name / component type).
--
-- Diff outcomes per child position:
--   - both old + new present with matching shape → reuse: keep the
--     existing Instance, apply only the changed attributes (which
--     tween for animatable properties via Elements.ApplyAttribute),
--     recurse into children.
--   - shape mismatch (different element name / kind / componentType)
--     → destroy old subtree, create new subtree.
--   - old longer than new → destroy the tail.
--   - new longer than old → create the tail.
--
-- Sequence numbers from RenderTreeBuilder are stored on nodes for
-- debugging only; v1 matches strictly by position. Reordering is
-- rare because Razor's emitted sequence numbers are stable across
-- renders, so the simpler positional algorithm covers real workloads.
--
-- Component nodes don't own the child component's Instances directly.
-- Each component has its own RenderHandle (created by the mountChild
-- callback the outer RenderHandle supplies), and that handle owns
-- its own reconciler state. On re-render, we forward the new
-- parameter set to the existing child component and trigger its
-- :_render — the child's own reconciler then diffs its own subtree.

local Elements = require(script.Parent.Elements)

local Reconciler = {}

-- Forward declarations so the helpers can call each other regardless
-- of file ordering. Keeping every helper `local` is what Luau strict
-- mode expects from ModuleScripts; bare `function name()` would
-- create globals, which can wedge the runtime in newer Luau modes.
local BuildTree
local ReconcileChildren
local ReconcileNode
local CreateNode
local DestroyNode
local ApplyAttributes
local ApplyAttributeDiff

-- Returns the new tree built by reconciling `oldTree` against the
-- frames. The caller (RenderHandle) stores the result and passes it
-- back on the next call so subsequent renders can diff incrementally.
function Reconciler.Reconcile(oldTree, frames, rootInstance, mountChild, refreshChild)
	local newTree = BuildTree(frames)
	ReconcileChildren(
		oldTree and oldTree.children or {},
		newTree.children,
		rootInstance,
		mountChild,
		refreshChild)
	return newTree
end

-- Tears down a tree completely. Used when the owning component is
-- unmounted; Reconcile handles partial teardown internally during
-- normal renders.
function Reconciler.Teardown(tree)
	if tree == nil then return end
	for _, child in ipairs(tree.children) do
		DestroyNode(child)
	end
end

-- Builds a tree from the flat frame list. The frames already obey
-- stack discipline (every Open is paired with an end), so we just
-- walk them and push/pop a stack of "current parent".
BuildTree = function(frames)
	local root = { kind = "root", children = {} }
	local stack = { root }

	for _, frame in ipairs(frames) do
		local top = stack[#stack]

		if frame.kind == "element" then
			local node = {
				kind = "element",
				seq = frame.seq,
				name = frame.name,
				attrs = {},
				children = {},
			}
			table.insert(top.children, node)
			table.insert(stack, node)

		elseif frame.kind == "component" then
			local node = {
				kind = "component",
				seq = frame.seq,
				componentType = frame.componentType,
				parameters = {},
				children = {},  -- unused; child component owns its own tree
			}
			table.insert(top.children, node)
			table.insert(stack, node)

		elseif frame.kind == "attribute" then
			if top.kind == "component" then
				top.parameters[frame.name] = frame.value
			else
				top.attrs[frame.name] = frame.value
			end

		elseif frame.kind == "content" then
			if top.kind == "component" then
				top.parameters.ChildContent = frame.content
			else
				table.insert(top.children, {
					kind = "content",
					seq = frame.seq,
					content = frame.content,
					children = {},  -- leaf
				})
			end

		elseif frame.kind == "ref" then
			-- Captures attach to whichever element they appear under.
			-- Refs on components route through AddComponentReferenceCapture
			-- (not implemented in v1); a ref frame on a component is
			-- silently dropped so a stray Razor emission doesn't crash.
			if top.kind == "element" then
				top.refs = top.refs or {}
				table.insert(top.refs, frame.capture)
			end

		elseif frame.kind == "end" then
			table.remove(stack)
		end
	end

	return root
end

-- Invokes every ref capture for an element with an ElementReference
-- pointing at its Instance. Same shape the C# struct compiles to (a
-- table with an Instance field), so the user's OnAfterRender can read
-- ref.Instance and pass it to TweenService directly.
local function InvokeRefs(node)
	if node.refs == nil then return end
	local ref = { Instance = node.instance }
	for _, capture in ipairs(node.refs) do
		capture(ref)
	end
end

-- Recursive child-array diff. Walks positions 1..max(#old, #new),
-- pairing old[i] vs new[i] and dispatching to ReconcileNode.
ReconcileChildren = function(oldChildren, newChildren, parentInstance, mountChild, refreshChild)
	local count = math.max(#oldChildren, #newChildren)
	for i = 1, count do
		ReconcileNode(oldChildren[i], newChildren[i], parentInstance, mountChild, refreshChild)
	end
end

-- Reconciles a single pair (either may be nil).
ReconcileNode = function(oldNode, newNode, parentInstance, mountChild, refreshChild)
	if newNode == nil then
		DestroyNode(oldNode)
		return
	end
	if oldNode == nil then
		CreateNode(newNode, parentInstance, mountChild, refreshChild)
		return
	end

	-- Shape mismatch: destroy the old subtree and create from scratch
	-- at this position. Detected by kind + element name + component type.
	if oldNode.kind ~= newNode.kind
		or oldNode.name ~= newNode.name
		or oldNode.componentType ~= newNode.componentType then
		DestroyNode(oldNode)
		CreateNode(newNode, parentInstance, mountChild, refreshChild)
		return
	end

	-- Same shape: reuse and apply incremental updates.
	if newNode.kind == "element" then
		newNode.instance = oldNode.instance
		-- Per-attribute teardown reuse: events whose handler value is
		-- unchanged across renders keep their existing connection,
		-- avoiding 64-tile-worth of disconnect/reconnect churn each
		-- click. Property writes only fire — and only tween — for
		-- attributes whose value actually changed.
		newNode.teardowns = ApplyAttributeDiff(
			newNode.instance, oldNode.attrs, newNode.attrs, oldNode.teardowns)
		InvokeRefs(newNode)
		ReconcileChildren(oldNode.children, newNode.children, newNode.instance, mountChild, refreshChild)

	elseif newNode.kind == "component" then
		-- Reuse the child component's RenderHandle. Forward the new
		-- parameter set and trigger its re-render — the child's own
		-- reconciler then diffs its own subtree against its previous one.
		newNode.childHandle = oldNode.childHandle
		refreshChild(newNode.childHandle, newNode.parameters)

	elseif newNode.kind == "content" then
		if newNode.content ~= oldNode.content then
			Elements.ApplyContent(parentInstance, newNode.content)
		end
	end
end

-- Materializes a new node and all its children under `parentInstance`.
-- Property writes during creation skip the tween path so newly-mounted
-- UI doesn't visibly fade in from each Instance's default values.
CreateNode = function(node, parentInstance, mountChild, refreshChild)
	if node.kind == "element" then
		node.instance = Elements.Create(node.name)
		node.instance.Parent = parentInstance
		node.teardowns = ApplyAttributes(node.instance, node.attrs)
		InvokeRefs(node)
		for _, child in ipairs(node.children) do
			CreateNode(child, node.instance, mountChild, refreshChild)
		end

	elseif node.kind == "component" then
		node.childHandle = mountChild(node.componentType, parentInstance, node.parameters)

	elseif node.kind == "content" then
		Elements.ApplyContent(parentInstance, node.content)
	end
end

-- Tears down a single node and everything below it. Children are
-- visited first so nested event teardowns fire and child components
-- Unmount cleanly — Roblox's Destroy cascade reaps Instance descendants
-- but doesn't invoke our lifecycle hooks.
DestroyNode = function(node)
	if node == nil then return end
	if node.children then
		for _, child in ipairs(node.children) do
			DestroyNode(child)
		end
	end
	if node.teardowns then
		-- teardowns is a map keyed by attribute name, not an array,
		-- so pairs (not ipairs) is what walks it.
		for _, disconnect in pairs(node.teardowns) do
			disconnect()
		end
	end
	if node.kind == "element" and node.instance then
		node.instance:Destroy()
	elseif node.kind == "component" and node.childHandle then
		node.childHandle:Unmount()
	end
end

-- Applies a full attribute map to a freshly-created Instance. No diff
-- (there's no previous value) and no animation (tweening from each
-- property's default would visibly fade the UI in from a blank state
-- on first mount). Returns event-disconnect teardowns keyed by
-- attribute name so the next reconcile pass can selectively drop or
-- reuse them.
ApplyAttributes = function(instance, attrs)
	local teardowns = {}
	for name, value in pairs(attrs) do
		local teardown = Elements.ApplyAttribute(instance, name, value, false)
		if teardown then
			teardowns[name] = teardown
		end
	end
	return teardowns
end

-- Applies the diff between two attribute maps. Unchanged values are
-- skipped entirely (property writes and tweens both). Events whose
-- attribute value is the same table/function reference across renders
-- keep their existing signal connection (no churn). Removed attributes
-- get their event connections disconnected; we don't reset their
-- Roblox-property values because there's no general "default" to write back.
ApplyAttributeDiff = function(instance, oldAttrs, newAttrs, oldTeardowns)
	oldTeardowns = oldTeardowns or {}
	local newTeardowns = {}
	for name, newValue in pairs(newAttrs) do
		local oldValue = oldAttrs[name]
		if oldValue == newValue and oldTeardowns[name] then
			-- Same event handler value — reuse the existing connection.
			newTeardowns[name] = oldTeardowns[name]
		elseif oldValue ~= newValue then
			-- Value changed (or first appearance). Disconnect any prior
			-- event for this attribute before re-applying.
			if oldTeardowns[name] then
				oldTeardowns[name]()
			end
			local teardown = Elements.ApplyAttribute(instance, name, newValue, true)
			if teardown then
				newTeardowns[name] = teardown
			end
		end
	end
	-- Attributes present last render but not this one: disconnect their
	-- events. Property values stick at their last-written state.
	for name, teardown in pairs(oldTeardowns) do
		if newAttrs[name] == nil and newTeardowns[name] == nil then
			teardown()
		end
	end
	return newTeardowns
end

return Reconciler
