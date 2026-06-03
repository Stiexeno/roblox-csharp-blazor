using System;

namespace Microsoft.AspNetCore.Components.Rendering
{
    /// <summary>
    /// Sequential frame writer that the Razor compiler — and hand-written
    /// <c>BuildRenderTree</c> overrides — call to describe a component's
    /// UI as flat open/attribute/content/close frames. The Luau runtime
    /// walks the frames and materializes a Roblox Instance tree.
    /// </summary>
    public class RenderTreeBuilder
    {
        /// <summary>Opens a Roblox element region; <paramref name="elementName"/> is the Instance class name (Frame, TextLabel, ImageButton, ...).</summary>
        public void OpenElement(int sequence, string elementName) { }

        /// <summary>Closes the most recently opened element.</summary>
        public void CloseElement() { }

        /// <summary>Opens a child component region; attributes between this and <see cref="CloseComponent"/> become its parameters.</summary>
        public void OpenComponent<TComponent>(int sequence) where TComponent : IComponent { }

        /// <summary>Closes the most recently opened component.</summary>
        public void CloseComponent() { }

        /// <summary>Sets a property or wires an event on the current open region. Names starting with <c>on</c> bind to Roblox signals.</summary>
        public void AddAttribute(int sequence, string name) { }

        /// <summary>Sets a property or wires an event on the current open region. Names starting with <c>on</c> bind to Roblox signals.</summary>
        public void AddAttribute(int sequence, string name, bool value) { }

        /// <summary>Sets a property or wires an event on the current open region. Names starting with <c>on</c> bind to Roblox signals.</summary>
        public void AddAttribute(int sequence, string name, string value) { }

        /// <summary>Sets a property or wires an event on the current open region. Names starting with <c>on</c> bind to Roblox signals.</summary>
        public void AddAttribute(int sequence, string name, object value) { }

        /// <summary>Wires an event on the current open region using a Blazor <see cref="EventCallback"/>.</summary>
        public void AddAttribute(int sequence, string name, EventCallback value) { }

        /// <summary>Wires a typed event on the current open region using a Blazor <see cref="EventCallback{T}"/>.</summary>
        public void AddAttribute<TArgument>(int sequence, string name, EventCallback<TArgument> value) { }

        /// <summary>Writes text content into the current open region (sets <c>.Text</c> if available, else creates a TextLabel child).</summary>
        public void AddContent(int sequence, string textContent) { }

        /// <summary>Writes object content into the current open region (stringified at runtime).</summary>
        public void AddContent(int sequence, object textContent) { }

        /// <summary>Invokes a nested <see cref="RenderFragment"/> in the current region.</summary>
        public void AddContent(int sequence, RenderFragment fragment) { }

        /// <summary>Writes pre-rendered markup verbatim. Roblox UI has no HTML, so this is a no-op for non-text contexts.</summary>
        public void AddMarkupContent(int sequence, string markupContent) { }

        /// <summary>Sets a named parameter on the currently open child component.</summary>
        public void AddComponentParameter(int sequence, string name, object value) { }

        /// <summary>
        /// Captures a reference to the Roblox Instance backing the currently
        /// open element. <paramref name="elementReferenceCaptureAction"/> is
        /// invoked with a populated <see cref="ElementReference"/> after the
        /// Instance is materialized, on every render the element survives.
        /// Razor's <c>@ref="field"</c> directive emits this call.
        /// </summary>
        public void AddElementReferenceCapture(int sequence, Action<ElementReference> elementReferenceCaptureAction) { }
    }
}
