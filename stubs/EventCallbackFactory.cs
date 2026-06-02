using System;

namespace Microsoft.AspNetCore.Components
{
    // Factory for constructing EventCallback instances. Razor's
    // generated @onclick code routes through here:
    //   EventCallback.Factory.Create(this, HandleClick)
    //
    // Two overloads handle the surface we need:
    //   - Action          — parameterless handlers (@onclick="OnClick"
    //                       where OnClick is void())
    //   - MulticastDelegate — anything else, after the transpiler's
    //                         RazorEventDirectiveRewriter has cast
    //                         the method group to its concrete
    //                         Action<TParam>. C# tie-breaking prefers
    //                         the Action overload when applicable, so
    //                         Action<T>-shaped handlers fall through to
    //                         MulticastDelegate as expected.
    //
    // The runtime sees only (receiver, callback) regardless of which
    // overload was picked — the transpiler drops cast expressions, and
    // the type-arg path generic overloads would otherwise force is
    // sidestepped entirely. Result: callers can write `@onTouched="OnTouched"`
    // on a Roblox Part the same way they write `@onclick="OnClick"` on
    // a TextButton, and the Luau output is uniform.
    public class EventCallbackFactory
    {
        public EventCallback Create(object receiver, Action callback) => null;

        public EventCallback Create(object receiver, MulticastDelegate callback) => null;
    }
}
