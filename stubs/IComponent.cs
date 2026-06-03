namespace Microsoft.AspNetCore.Components
{
    /// <summary>
    /// Marker every renderable Blazor component implements. Inherit
    /// <see cref="ComponentBase"/> instead of implementing this directly
    /// unless you need to bypass the standard lifecycle.
    /// </summary>
    public interface IComponent
    {
    }
}
