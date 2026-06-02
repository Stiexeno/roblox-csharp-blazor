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
--
-- The 2-arg form (no value) is Razor's degraded "minimized attribute"
-- shape: a literal-empty `Foo=""` on an unknown element compiles down
-- to `AddAttribute(seq, "Foo")` with no value at all. HTML reads that
-- as `Foo=true`, but Roblox properties are statically typed — there's
-- no universal sensible coercion. Skip the frame; the user can pass
-- an explicit value (`Foo="@(string.Empty)"`) when they want the
-- attribute applied with an empty payload.
function RenderTreeBuilder:AddAttribute(seq, name, value)
	if value == nil then return end
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
	-- A RenderFragment is delegate(RenderTreeBuilder) → void. Razor
	-- both emits literal `AddContent(N, fragmentExpr)` AND passes
	-- RenderFragment-typed [Parameter] values through this method,
	-- so any callable here means "expand the fragment into our frame
	-- list now" — recurse with self so the fragment's builder ops
	-- land inline rather than as a stringified function reference.
	if type(content) == "function" then
		content(self)
		return
	end
	table.insert(self._frames, {
		kind = "content",
		seq = seq,
		content = content,
	})
end

-- Razor emits this for literal text inside RenderFragments and for
-- pretty-printing whitespace between sibling elements (`<a/>\n\t<b/>`
-- compiles to AddMarkupContent of "\n\t" between the two opens).
-- Pure-whitespace content is source-formatting noise — it has no
-- user-intended rendering and would otherwise force an ApplyContent
-- write on the parent (creating extra TextLabel children inside
-- containers like ImageButton that lack a .Text property). Filter
-- it here. Non-whitespace text still routes to AddContent.
function RenderTreeBuilder:AddMarkupContent(seq, content)
	if type(content) == "string" and string.match(content, "^%s*$") ~= nil then
		return
	end
	self:AddContent(seq, content)
end

-- Razor emits this for component parameter passes. The runtime
-- treats it identically to AddAttribute — the reconciler already
-- routes attribute frames to a component sink when the current
-- open region is a component, so a parallel "parameter" frame kind
-- would just be redundant book-keeping.
function RenderTreeBuilder:AddComponentParameter(seq, name, value)
	self:AddAttribute(seq, name, value)
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
