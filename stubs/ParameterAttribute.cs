using System;

namespace Microsoft.AspNetCore.Components
{
    /// <summary>
    /// Marks a public property as a component parameter — the parent component
    /// (or Razor markup) sets it on every render before <c>OnParametersSet</c>.
    /// </summary>
    [AttributeUsage(AttributeTargets.Property, AllowMultiple = false)]
    public class ParameterAttribute : Attribute
    {
        /// <summary>
        /// Capture every unmatched attribute on the parent element into this
        /// property's dictionary. Useful for splatting HTML-style attribute bags.
        /// </summary>
        public bool CaptureUnmatchedValues { get; set; }
    }
}
