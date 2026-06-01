using System;

namespace Microsoft.AspNetCore.Components
{
    // Marks a public property as DI-injected when the component is
    // mounted. Not wired in v1 — listed here so .razor files using
    // [Inject] compile; runtime support arrives once the Blazor
    // plugin and the DI plugin agree on a handshake.
    [AttributeUsage(AttributeTargets.Property, AllowMultiple = false)]
    public class InjectAttribute : Attribute
    {
    }
}
