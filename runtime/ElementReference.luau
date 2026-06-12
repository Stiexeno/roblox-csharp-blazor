-- Backs `new ElementReference(instance)` in user code. The reconciler
-- itself hands ref captures plain `{ Instance = instance }` tables
-- (see Reconciler's InvokeRefs) — same field shape, no metatable —
-- so anything that only reads `.Instance` treats both forms alike.
-- This module exists so a user-side construction compiles to a real
-- module instead of an import pointing at nothing.

local ElementReference = {}
ElementReference.__index = ElementReference

setmetatable(ElementReference, {
	__tostring = function() return "ElementReference" end,
})

function ElementReference.new(...)
	local self = setmetatable({}, ElementReference)
	return self:constructor(...) or self
end

ElementReference.__ctorParams = {}
ElementReference.__interfaces = {}

function ElementReference:constructor(instance)
	self.Instance = instance
end

return ElementReference
