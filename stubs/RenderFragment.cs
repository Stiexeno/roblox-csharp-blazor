using Microsoft.AspNetCore.Components.Rendering;

namespace Microsoft.AspNetCore.Components
{
    /// <summary>
    /// A piece of UI written as a delegate over <see cref="RenderTreeBuilder"/>.
    /// Used to pass child content into a component, e.g. <c>ChildContent</c> parameters.
    /// </summary>
    public delegate void RenderFragment(RenderTreeBuilder builder);

    /// <summary>
    /// Parameterized render fragment — bind a value, get back a
    /// <see cref="RenderFragment"/> that closes over it.
    /// </summary>
    public delegate RenderFragment RenderFragment<TValue>(TValue value);
}
