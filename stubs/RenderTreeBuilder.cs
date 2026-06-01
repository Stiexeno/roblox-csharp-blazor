namespace Microsoft.AspNetCore.Components.Rendering
{
    // The render-tree builder passed into BuildRenderTree. Razor's
    // generated code drives this; hand-written components can too.
    //
    // Sequence numbers are positional, not stable identifiers. The
    // reconciler uses them to pair frames between renders only when
    // nothing has shifted around.
    //
    // Overload set is the realistic subset Razor emits — value,
    // string, bool, EventCallback, RenderFragment, plus the generic
    // OpenComponent<T>. Additional overloads can be added later
    // without breaking the wire format.
    public class RenderTreeBuilder
    {
        public void OpenElement(int sequence, string elementName) { }

        public void CloseElement() { }

        public void OpenComponent<TComponent>(int sequence) where TComponent : IComponent { }

        public void CloseComponent() { }

        public void AddAttribute(int sequence, string name) { }

        public void AddAttribute(int sequence, string name, bool value) { }

        public void AddAttribute(int sequence, string name, string value) { }

        public void AddAttribute(int sequence, string name, object value) { }

        public void AddAttribute(int sequence, string name, EventCallback value) { }

        public void AddAttribute<TArgument>(int sequence, string name, EventCallback<TArgument> value) { }

        public void AddContent(int sequence, string textContent) { }

        public void AddContent(int sequence, object textContent) { }

        public void AddContent(int sequence, RenderFragment fragment) { }

        // Razor emits this for literal text inside RenderFragments.
        // Runtime treats it identically to AddContent — the
        // "markup-vs-content" distinction only matters in HTML Blazor
        // (for HTML escaping); we just write a string.
        public void AddMarkupContent(int sequence, string markupContent) { }

        // Razor emits this for component parameter passes — e.g.
        // <MyComp Foo="bar"/> becomes AddComponentParameter(N, "Foo", "bar").
        // Distinct from AddAttribute so component params don't accidentally
        // wire up as element-level event signals in the runtime.
        public void AddComponentParameter(int sequence, string name, object value) { }
    }
}
