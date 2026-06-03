using DependencyInjection;
using Microsoft.AspNetCore.Components;

namespace Blazor
{
    /// <summary>
    /// Entry point for mounting a Blazor-style component into a Roblox
    /// Instance subtree. Returns a <see cref="RenderHandle"/> for teardown.
    /// </summary>
    public static class Renderer
    {
        /// <summary>
        /// Constructs <typeparamref name="TComponent"/>, parents it under
        /// <paramref name="parentInstance"/>, and drives the first render.
        /// Pass an <see cref="IInstantiator"/> to wire constructor injection.
        /// </summary>
        public static RenderHandle Mount<TComponent>(object parentInstance, IInstantiator instantiator) where TComponent : IComponent => null;
    }
}
