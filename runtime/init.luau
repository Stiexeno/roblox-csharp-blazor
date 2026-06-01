-- Entry point for the Blazor plugin. Exports the public surface for
-- user code (`Component`, `Renderer`, `RenderTreeBuilder`) plus the
-- types Razor-generated code references. Nothing here has side
-- effects — mounting a UI is the user's call via Renderer.Mount.

return {
	ComponentBase = require(script.ComponentBase),
	Renderer = require(script.Renderer),
	RenderTreeBuilder = require(script.RenderTreeBuilder),
	RenderHandle = require(script.RenderHandle),
	EventCallback = require(script.EventCallback),
	EventCallbackFactory = require(script.EventCallbackFactory),
	RuntimeHelpers = require(script.RuntimeHelpers),
}
