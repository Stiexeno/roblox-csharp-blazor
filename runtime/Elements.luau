-- Element vocabulary + attribute application. The reconciler hands
-- this module element/attribute frames and gets back ready-to-parent
-- Roblox Instances with properties and event signals wired up.
--
-- Naming:
--   - Element tag names are passed through verbatim to Instance.new.
--     Roblox is the source of truth for what's a valid UI class; an
--     unknown name surfaces as the engine's own "Unable to create" error.
--   - Attribute names beginning with `on` are treated as event hooks.
--     Curated map covers common Blazor-style names (onclick → MouseButton1Click);
--     anything else strips the `on` prefix and looks up a signal of that
--     exact name on the instance (so `onMouseWheelForward` → MouseWheelForward).
--   - Other attribute names are written as Roblox properties verbatim
--     (`Size`, `BackgroundColor3`, `Visible`, etc.). When the reconciler
--     marks a write as "animate" (Instance survived from a prior render)
--     and the property is tweenable, the write is wrapped in a TweenService
--     tween instead of an instant assignment.

local TweenService = game:GetService("TweenService")

local Elements = {}

-- Default tween used for animated property writes. Quad/Out is a good
-- default for game UI: fast start, smooth deceleration. The duration
-- is short enough that rapid input feedback still feels responsive.
local DEFAULT_TWEEN_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Properties whose writes Roblox can interpolate. Animated writes to
-- other properties (Text, Visible, LayoutOrder, …) fall back to instant
-- assignment because TweenService rejects them.
local TWEENABLE_PROPS = {
	Position = true,
	Size = true,
	AnchorPoint = true,
	Rotation = true,
	BackgroundColor3 = true,
	BackgroundTransparency = true,
	BorderColor3 = true,
	BorderSizePixel = true,
	ImageColor3 = true,
	ImageTransparency = true,
	Color = true,
	TextColor3 = true,
	TextTransparency = true,
	TextStrokeColor3 = true,
	TextStrokeTransparency = true,
	Transparency = true,
	Scale = true,            -- UIScale.Scale
	Thickness = true,        -- UIStroke.Thickness
}

-- Per-instance map of currently-running tweens, keyed by property name.
-- Weak keys so the table doesn't pin Instances after the reconciler
-- destroys them; Roblox will GC the entry once nothing else holds a
-- reference. Lets us cancel a prior tween before starting a new one
-- on the same property so consecutive renders don't produce competing
-- interpolations that visually fight each other.
local ActiveTweens = setmetatable({}, { __mode = "k" })

-- Cache of fallback TextLabels we created when ApplyContent was asked
-- to render text into an Instance that doesn't expose a Text property
-- (ImageButton, plain Frame, etc.). Keyed by the parent Instance so a
-- subsequent ApplyContent call updates the existing label's Text in
-- place rather than parenting a second one over it. Weak keys for the
-- same reason as ActiveTweens.
local FallbackTextLabels = setmetatable({}, { __mode = "k" })

-- Curated Blazor-style → Roblox signal mappings. Lowercase keys so
-- user code can write @onclick exactly like Blazor; the property
-- branch is case-sensitive so Roblox property names ("BackgroundColor3")
-- still pass through verbatim.
local EVENT_MAP = {
	onclick = "MouseButton1Click",
	onrightclick = "MouseButton2Click",
	onmousedown = "MouseButton1Down",
	onmouseup = "MouseButton1Up",
	onmouseenter = "MouseEnter",
	onmouseleave = "MouseLeave",
	onactivated = "Activated",
	onfocus = "Focused",
	onblur = "FocusLost",
	oninputbegan = "InputBegan",
	oninputended = "InputEnded",
}

function Elements.Create(name)
	-- Defensive guard: a dotted name would let a malformed render tree
	-- reach into the data model via Instance.new("Workspace.Foo"), which
	-- isn't a thing Roblox supports but isn't worth taking chances on.
	if string.find(name, ".", 1, true) then
		error(string.format("[Blazor] Invalid element name %q", name), 2)
	end
	return Instance.new(name)
end

-- Returns (isEvent, signalNameOrPropertyName). The reconciler uses the
-- first return to decide whether to Connect or assign.
local function classifyAttribute(name)
	local mapped = EVENT_MAP[string.lower(name)]
	if mapped ~= nil then
		return true, mapped
	end
	-- Pass-through escape hatch: attribute names that start with "on"
	-- followed by an uppercase letter are treated as direct signal names.
	-- Lets users wire any Roblox event without us curating it.
	if #name > 2 and string.sub(name, 1, 2) == "on" then
		local rest = string.sub(name, 3)
		local first = string.sub(rest, 1, 1)
		if first >= "A" and first <= "Z" then
			return true, rest
		end
	end
	return false, name
end

-- Starts an animated property write. Cancels any in-flight tween on
-- the same (instance, property) so the latest target wins instead of
-- two tweens fighting. Cleared from the bookkeeping table when the
-- tween completes or is cancelled.
local function tweenProperty(instance, key, value)
	local perInstance = ActiveTweens[instance]
	if perInstance and perInstance[key] then
		perInstance[key]:Cancel()
	end

	local tween = TweenService:Create(instance, DEFAULT_TWEEN_INFO, { [key] = value })
	if perInstance == nil then
		perInstance = {}
		ActiveTweens[instance] = perInstance
	end
	perInstance[key] = tween
	tween:Play()
	tween.Completed:Once(function()
		if ActiveTweens[instance] and ActiveTweens[instance][key] == tween then
			ActiveTweens[instance][key] = nil
		end
	end)
end

-- Applies one attribute frame to `instance`. Returns a teardown
-- function ONLY for events (so the reconciler can Disconnect on
-- unmount or attribute replacement); property writes return nil
-- because there's nothing to undo.
--
-- `animate` is true when this Instance survived from the previous
-- render and the property is eligible for a tweened transition; the
-- reconciler passes false on initial creation so newly-mounted UI
-- doesn't fade in from each property's default value.
function Elements.ApplyAttribute(instance, attrName, attrValue, animate)
	local isEvent, key = classifyAttribute(attrName)
	if isEvent then
		local signal = instance[key]
		if signal == nil then
			error(string.format(
				"[Blazor] %s has no signal %q (from attribute %q)",
				instance.ClassName, key, attrName), 2)
		end
		local connection = signal:Connect(function(...)
			-- attrValue is either a raw function or an EventCallback
			-- table { _invoke = function }. Support both shapes so
			-- hand-written Lua and Razor-generated code both work.
			if type(attrValue) == "function" then
				attrValue(...)
			elseif type(attrValue) == "table" and attrValue._invoke then
				attrValue._invoke(...)
			end
		end)
		return function() connection:Disconnect() end
	end

	if animate and TWEENABLE_PROPS[key] then
		local ok, err = pcall(tweenProperty, instance, key, attrValue)
		if ok then
			return nil
		end
		-- Fall through to instant assignment on tween failure (e.g.,
		-- TweenService rejected the value type). Better to write the
		-- value than to drop it silently.
		warn(string.format(
			"[Blazor] Tween failed for %s.%s, falling back to direct assignment: %s",
			instance.ClassName, key, tostring(err)))
	end

	-- Property write. Wrapped in pcall so an unknown property surfaces
	-- with the attribute name we tried, not Roblox's generic
	-- "Unable to assign property X" which loses the Blazor context.
	local ok, err = pcall(function()
		instance[key] = attrValue
	end)
	if not ok then
		error(string.format(
			"[Blazor] Failed to set %s.%s: %s",
			instance.ClassName, key, tostring(err)), 2)
	end
	return nil
end

-- Applies a text-content frame. If the instance has a Text property
-- (TextLabel / TextButton / TextBox), writes to it; otherwise creates
-- (or reuses) a child TextLabel so loose text inside non-text containers
-- still renders rather than being silently dropped.
--
-- The fallback TextLabel is cached per parent — a subsequent
-- ApplyContent call with different content updates the existing label's
-- Text in place rather than parenting a second TextLabel over the first
-- (which would leak the old label and render both, overlapping).
function Elements.ApplyContent(instance, content)
	local text = tostring(content)
	-- pcall the read because some Instances raise when an unknown
	-- property is accessed via indexing — we use the success of the
	-- read as a feature-detect for "supports Text".
	local hasText = pcall(function() return instance.Text end)
	if hasText then
		instance.Text = text
		return
	end

	local existing = FallbackTextLabels[instance]
	if existing and existing.Parent == instance then
		existing.Text = text
		return
	end

	local label = Instance.new("TextLabel")
	label.Text = text
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Parent = instance
	FallbackTextLabels[instance] = label
end

return Elements
