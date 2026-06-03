using RobloxCSharp.RobloxApi;

namespace Microsoft.AspNetCore.Components
{
    /// <summary>
    /// Captured handle to the Roblox Instance backing an element in the
    /// render tree. Bind via the <c>@ref</c> Razor directive (or call
    /// <c>RenderTreeBuilder.AddElementReferenceCapture</c> directly) and
    /// read <see cref="Instance"/> in <c>OnAfterRender</c> to drive
    /// TweenService animations, attach physics, or otherwise reach the
    /// underlying object that the declarative render tree built.
    /// </summary>
    public struct ElementReference
    {
        /// <summary>The Roblox Instance the ref points at, or <c>null</c> before the first render fires the capture.</summary>
        public Instance Instance { get; }

        public ElementReference(Instance instance) { Instance = instance; }
    }
}
