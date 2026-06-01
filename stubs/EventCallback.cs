namespace Microsoft.AspNetCore.Components
{
    // EventCallback wraps a handler so the renderer can invoke it
    // without needing a direct delegate reference. In real Blazor
    // it's a struct that knows about the receiving component for
    // automatic StateHasChanged dispatch; our runtime treats it as
    // an opaque table with an _invoke field, so the stub can stay
    // a class without changing call-site semantics.
    public class EventCallback
    {
        public static readonly EventCallbackFactory Factory = new EventCallbackFactory();

        public void InvokeAsync() { }
        public void InvokeAsync(object arg) { }
    }

    public class EventCallback<TValue>
    {
        public void InvokeAsync(TValue arg) { }
    }
}
