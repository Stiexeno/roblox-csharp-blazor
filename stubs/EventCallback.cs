namespace Microsoft.AspNetCore.Components
{
    /// <summary>
    /// Typed event handler wired through <see cref="EventCallback.Factory"/> so the
    /// owning component re-renders when the callback fires. Bind via
    /// <c>@onclick</c> in Razor, or pass to <c>RenderTreeBuilder.AddAttribute</c>.
    /// </summary>
    public class EventCallback
    {
        public static readonly EventCallbackFactory Factory = new EventCallbackFactory();

        public void InvokeAsync() { }
        public void InvokeAsync(object arg) { }
    }

    /// <summary>
    /// Generic variant of <see cref="EventCallback"/> for callbacks that carry
    /// a typed payload.
    /// </summary>
    public class EventCallback<TValue>
    {
        public void InvokeAsync(TValue arg) { }
    }
}
