using Microsoft.AspNetCore.Components;

namespace Blazor
{
    // Mount entry point. Users call Renderer.Mount<App>(parent) from
    // their bootstrap code; the runtime instantiates the component,
    // attaches a render handle, and drives the first render. The
    // returned handle can be Unmounted to tear down cleanly — useful
    // for hot-reload and test harnesses.
    public static class Renderer
    {
        public static RenderHandle Mount<TComponent>(object parentInstance) where TComponent : IComponent => null;
    }
}
