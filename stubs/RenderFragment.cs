using Microsoft.AspNetCore.Components.Rendering;

namespace Microsoft.AspNetCore.Components
{
    // Delegate types Razor uses to model "child content" — a piece
    // of UI authored at the use-site of a component, passed in as
    // a parameter. <MyComp>text</MyComp> compiles to assigning a
    // RenderFragment to the ChildContent parameter.
    public delegate void RenderFragment(RenderTreeBuilder builder);

    public delegate RenderFragment RenderFragment<TValue>(TValue value);
}
