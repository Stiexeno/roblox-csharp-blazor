namespace Blazor
{
    // Opaque handle returned by Renderer.Mount. The runtime drives
    // re-renders internally (via StateHasChanged); the handle's only
    // consumer-facing job is Unmount, which detaches everything
    // cleanly — used by hot-reload and test harnesses.
    public class RenderHandle
    {
        public void Unmount() { }
    }
}
