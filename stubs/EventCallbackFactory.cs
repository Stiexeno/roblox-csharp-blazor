using System;

namespace Microsoft.AspNetCore.Components
{
    // Factory for constructing EventCallback instances. Razor's
    // generated @onclick code routes through here:
    //   EventCallback.Factory.Create(this, HandleClick)
    public class EventCallbackFactory
    {
        public EventCallback Create(object receiver, Action callback) => null;

        public EventCallback Create(object receiver, Action<object> callback) => null;

        public EventCallback<TValue> Create<TValue>(object receiver, Action<TValue> callback) => null;

        public EventCallback Create(object receiver, EventCallback callback) => null;

        public EventCallback<TValue> Create<TValue>(object receiver, EventCallback<TValue> callback) => null;
    }
}
