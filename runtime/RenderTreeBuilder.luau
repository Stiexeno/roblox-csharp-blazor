-- Render-tree builder. Mirrors Blazor's RenderTreeBuilder API: the
-- Razor compiler (or hand-written BuildRenderTree code) drives it
-- with OpenElement / AddAttribute / AddContent / OpenComponent /
-- CloseComponent / CloseElement keyed by integer sequence numbers.
--
-- Sequence numbers are positional, not stable identifiers. The
-- reconciler uses them to pair frames between renders only when
-- nothing has shifted; shifted sequences fall back to subtree
-- replacement, matching how real Blazor degrades.
--
-- Frame shapes:
--   { kind = "element",   seq, name }
--   { kind = "component", seq, componentType }
--   { kind = "attribute", seq, name, value }
--   { kind = "content",   seq, content }
--   { kind = "end" }
--
-- The frame list is flat; opens and closes are paired by stack
-- discipline. GetFrames asserts balance so a missing CloseElement
-- surfaces as a render-time error instead of a silent half-tree.

local RenderTreeBuilder = {}
RenderTreeBuilder.__index = RenderTreeBuilder

setmetatable(RenderTreeBuilder, {
	__tostring = function() return "RenderTreeBuilder" end,
})

function RenderTreeBuilder.new(...)
	local self = setmetatable({}, RenderTreeBuilder)
	return self:constructor(...) or self
end

-- No __ctorParams entries: the reconciler constructs RenderTreeBuilder
-- itself once per render, not through DI.
RenderTreeBuilder.__ctorParams = {}
RenderTreeBuilder.__interfaces = {}

function RenderTreeBuilder:constructor()
	self._frames = {}
	self._openDepth = 0
end

function RenderTreeBuilder:OpenElement(seq, name)
	table.insert(self._frames, { kind = "element", seq = seq, name = name })
	self._openDepth += 1
end

function RenderTreeBuilder:CloseElement()
	if self._openDepth == 0 then
		error("[Blazor] CloseElement called without a matching OpenElement", 2)
	end
	table.insert(self._frames, { kind = "end" })
	self._openDepth -= 1
end

function RenderTreeBuilder:OpenComponent(seq, componentType)
	table.insert(self._frames, {
		kind = "component",
		seq = seq,
		componentType = componentType,
	})
	self._openDepth += 1
end

function RenderTreeBuilder:CloseComponent()
	if self._openDepth == 0 then
		error("[Blazor] CloseComponent called without a matching OpenComponent", 2)
	end
	table.insert(self._frames, { kind = "end" })
	self._openDepth -= 1
end

-- Attributes attach to whichever open region (element or component)
-- they appear under. The reconciler resolves that by scanning back
-- to the nearest unclosed open frame, so we don't track the target
-- here — keeps the builder purely append-only.
function RenderTreeBuilder:AddAttribute(seq, name, value)
	table.insert(self._frames, {
		kind = "attribute",
		seq = seq,
		name = name,
		value = value,
	})
end

function RenderTreeBuilder:AddContent(seq, content)
	-- Skip nil/empty content frames — they show up when an interpolated
	-- expression evaluates to nil and would otherwise force a Text-prop
	-- write of "nil" on the parent.
	if content == nil then return end
	table.insert(self._frames, {
		kind = "content",
		seq = seq,
		content = content,
	})
end

function RenderTreeBuilder:GetFrames()
	if self._openDepth ~= 0 then
		error(string.format(
			"[Blazor] Unbalanced render tree: %d unclosed region(s)",
			self._openDepth), 2)
	end
	return self._frames
end

return RenderTreeBuilder
