-- Razor-generated component parameter passes are wrapped in
-- RuntimeHelpers.TypeCheck<T>(value) to make the C# compiler reject
-- type-mismatched parameter writes. At runtime it's an identity
-- function — Luau doesn't enforce static types and there's nothing
-- meaningful to check.

local RuntimeHelpers = {}

function RuntimeHelpers.TypeCheck(value)
	return value
end

return RuntimeHelpers
