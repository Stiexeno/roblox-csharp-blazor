namespace Microsoft.AspNetCore.Components.CompilerServices
{
    /// <summary>
    /// Razor compiler shim. <see cref="TypeCheck{T}"/> is emitted by the
    /// Razor codegen to enforce expected types on event handlers; at runtime
    /// it's an identity function.
    /// </summary>
    public static class RuntimeHelpers
    {
        public static T TypeCheck<T>(T value) => value;
    }
}
