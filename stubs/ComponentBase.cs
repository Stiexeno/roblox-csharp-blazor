using Microsoft.AspNetCore.Components.Rendering;

namespace Microsoft.AspNetCore.Components
{
    /// <summary>
    /// Base class for Blazor-style components. Override <see cref="BuildRenderTree"/>
    /// (or write a <c>.razor</c> file) to describe the UI; call
    /// <see cref="StateHasChanged"/> after mutating state to trigger a re-render.
    /// </summary>
    public abstract class ComponentBase : IComponent
    {
        /// <summary>Lifecycle hook; called once before the first render.</summary>
        protected virtual void OnInitialized() { }

        /// <summary>Lifecycle hook; called every render after parameters apply.</summary>
        protected virtual void OnParametersSet() { }

        /// <summary>Lifecycle hook; called after each render. <paramref name="firstRender"/> is true only on the first one.</summary>
        protected virtual void OnAfterRender(bool firstRender) { }

        /// <summary>Override to describe the component's UI by writing frames into <paramref name="builder"/>.</summary>
        protected virtual void BuildRenderTree(RenderTreeBuilder builder) { }

        /// <summary>Signals that state changed; the renderer schedules a re-render of this subtree.</summary>
        protected void StateHasChanged() { }
    }
}
