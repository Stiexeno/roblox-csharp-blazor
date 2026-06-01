using DependencyInjection;
using Microsoft.AspNetCore.Components;

namespace Blazor
{
    // Mount entry point. Users call Renderer.Mount<App>(parent, instantiator)
    // from their bootstrap code; the runtime constructs the component
    // via IInstantiator (so its constructor params get DI-resolved),
    // attaches a render handle, and drives the first render. The
    // returned handle can be Unmounted to tear down cleanly — useful
    // for hot-reload and test harnesses.
    //
    // IInstantiator is auto-bound by the DI Container, so callers
    // typically ctor-inject IInstantiator themselves and forward it
    // here. Component construction routes through Instantiate<T>(),
    // which resolves ctor params from the container's bindings.
    // Components with parameterless constructors still work —
    // Instantiate just sees an empty __ctorParams and calls new() with
    // no args. There is no property/field injection ([Inject] is a
    // no-op marker); inject everything through the constructor.
    public static class Renderer
    {
        public static RenderHandle Mount<TComponent>(object parentInstance, IInstantiator instantiator) where TComponent : IComponent => null;
    }
}
