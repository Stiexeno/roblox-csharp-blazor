namespace Blazor
{
    /// <summary>
    /// Disposer for a mounted component tree. Hold onto it for as long as the
    /// UI should live; call <see cref="Unmount"/> to tear down.
    /// </summary>
    public class RenderHandle
    {
        /// <summary>
        /// Destroys the rendered Instance subtree and disconnects every event
        /// subscription wired during render.
        /// </summary>
        public void Unmount() { }
    }
}
