using System;

namespace Microsoft.AspNetCore.Components
{
    /// <summary>
    /// Marks a property to be resolved from the DI container at mount time.
    /// Declared so <c>.razor</c> files using <c>[Inject]</c> compile; wiring
    /// is deferred until a future release.
    /// </summary>
    [AttributeUsage(AttributeTargets.Property, AllowMultiple = false)]
    public class InjectAttribute : Attribute
    {
    }
}
