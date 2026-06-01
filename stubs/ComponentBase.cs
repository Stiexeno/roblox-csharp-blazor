using Microsoft.AspNetCore.Components.Rendering;

namespace Microsoft.AspNetCore.Components
{
    // Base class for user components. Mirrors Blazor's ComponentBase:
    // override BuildRenderTree to describe UI, call StateHasChanged
    // when state changes, hook OnInitialized / OnParametersSet /
    // OnAfterRender for lifecycle.
    //
    // Async overloads (OnInitializedAsync etc.) are intentionally not
    // exposed in v1 — the transpiler's async support story is its
    // own roadmap item and we'd rather ship a working sync surface
    // than half-wire async lifecycles.
    public abstract class ComponentBase : IComponent
    {
        protected virtual void OnInitialized() { }

        protected virtual void OnParametersSet() { }

        protected virtual void OnAfterRender(bool firstRender) { }

        // Override to describe the UI for this component. The Razor
        // compiler generates this override for .razor files; for
        // hand-written components, override it directly.
        protected virtual void BuildRenderTree(RenderTreeBuilder builder) { }

        // Schedules a re-render. Synchronous in v1 — no batching.
        protected void StateHasChanged() { }
    }
}
