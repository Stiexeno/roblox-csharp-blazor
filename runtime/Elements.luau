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
--     (`Size`, `BackgroundColor3`, `Visible`, etc.).

local Elements = {}

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

-- Applies one attribute frame to `instance`. Returns a teardown
-- function ONLY for events (so the reconciler can Disconnect on
-- unmount or attribute replacement); property writes return nil
-- because there's nothing to undo.
function Elements.ApplyAttribute(instance, attrName, attrValue)
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
-- a child TextLabel so loose text inside non-text containers still
-- renders rather than being silently dropped.
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
	local label = Instance.new("TextLabel")
	label.Text = text
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Parent = instance
end

return Elements
