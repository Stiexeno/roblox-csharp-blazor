using System;

namespace Microsoft.AspNetCore.Components
{
    /// <summary>
    /// Constructs <see cref="EventCallback"/> instances bound to a receiver
    /// component. Access via <see cref="EventCallback.Factory"/> — the Razor
    /// compiler emits factory calls for <c>@onXxx</c> directives.
    /// </summary>
    public class EventCallbackFactory
    {
        public EventCallback Create(object receiver, Action callback) => null;

        public EventCallback Create(object receiver, MulticastDelegate callback) => null;
    }
}
