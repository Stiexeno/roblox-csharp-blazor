using System;

namespace Microsoft.AspNetCore.Components
{
    // Authoring-time marker for component parameters. Mirrors
    // Blazor's [Parameter] — the transpiler doesn't read it at
    // runtime (parameter writes are plain field assignments by
    // name in the Luau runtime), but Razor-generated component
    // code references the attribute and IDE tooling uses it for
    // intellisense, so the type has to exist.
    [AttributeUsage(AttributeTargets.Property, AllowMultiple = false)]
    public class ParameterAttribute : Attribute
    {
        public bool CaptureUnmatchedValues { get; set; }
    }
}
