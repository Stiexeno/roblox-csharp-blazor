namespace Microsoft.AspNetCore.Components.CompilerServices
{
    // Razor-generated code wraps strongly-typed component parameter
    // passes in RuntimeHelpers.TypeCheck<T>(value) — at runtime it's
    // an identity function whose job is to make the C# compiler
    // refuse the call if `value` isn't assignable to T. The transpiler
    // doesn't enforce that (Luau is dynamically typed); we just pass
    // the value through.
    public static class RuntimeHelpers
    {
        public static T TypeCheck<T>(T value) => value;
    }
}
