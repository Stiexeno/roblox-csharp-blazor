namespace RobloxCSharp.Extensions.Blazor
{
    /// <summary>
    /// Lets users write `<Frame>`, `<TextLabel>`, etc. in `.razor` files
    /// without Razor (and Rider's Razor-aware editor) treating them as
    /// obsolete HTML elements.
    ///
    /// The Blazor plugin's `stubs/ElementTags.cs` declares empty
    /// `ComponentBase` shims (`RobloxCSharp.Blazor.Tags.Frame`, …) and
    /// pulls them into Razor scope via `_Imports.razor`. The Razor
    /// compiler then resolves PascalCase tags to those shims and emits:
    ///
    /// <code>
    /// __builder.OpenComponent&lt;Tags.Frame&gt;(0);
    /// __builder.AddAttribute(1, "Size", value);
    /// __builder.CloseComponent();
    /// </code>
    ///
    /// We rewrite the `OpenComponent&lt;Tags.X&gt;` call to
    /// `OpenElement(seq, "X")`. `CloseComponent` and `CloseElement`
    /// emit the same `end` frame at the runtime builder layer, so
    /// no rewrite is needed on the close side.
    ///
    /// The shim's empty `BuildRenderTree` never runs because the
    /// rewritten call goes straight to OpenElement.
    /// </summary>
    public sealed class BlazorTagElementOverride : IRobloxCSharpExtension
    {
        private const string OpenComponentMethod = "OpenComponent";
        private const string OpenElementMethod = "OpenElement";
        private const string TagsNamespace = "RobloxCSharp.Blazor.Tags";

        // Shim names that map to a different Roblox class name. The
        // alias exists because Razor / Rider's HTML inspector
        // case-folds tag names against its HTML schema; PascalCase
        // shim names that collide with deprecated HTML elements
        // (most notably "Frame") get strikethrough styling that
        // isn't configurable per project. Re-emit them under their
        // real Roblox class name so the runtime still creates the
        // correct Instance.
        private static readonly Dictionary<string, string> ShimToRobloxClass = new()
        {
            ["Rect"] = "Frame",
        };

        public string Name => "Blazor.TagElementOverride";

        public void OnCompile(Compilation compilation, IReadOnlyList<Plugin> plugins, DiagnosticBag diagnostics)
        {
        }

        public LuaNode TryRewrite(SyntaxNode syntax, TransformerState state)
        {
            if (syntax is not InvocationExpressionSyntax invocation) return null;
            if (invocation.Expression is not MemberAccessExpressionSyntax memberAccess) return null;
            if (memberAccess.Name is not GenericNameSyntax generic) return null;
            if (generic.Identifier.Text != OpenComponentMethod) return null;
            if (generic.TypeArgumentList.Arguments.Count != 1) return null;

            ITypeSymbol typeArg = state.SemanticModel
                .GetTypeInfo(generic.TypeArgumentList.Arguments[0]).Type;
            if (!IsTagShim(typeArg)) return null;

            if (invocation.ArgumentList.Arguments.Count != 1) return null;

            LuaExpression target = state.Transform(memberAccess.Expression) as LuaExpression;
            LuaExpression seqArg = state.Transform(invocation.ArgumentList.Arguments[0].Expression) as LuaExpression;
            if (target is null || seqArg is null) return null;

            string robloxClass = ShimToRobloxClass.TryGetValue(typeArg.Name, out string mapped)
                ? mapped
                : typeArg.Name;

            LuaInvocationExpression call = new(LuaFactory.MemberAccess(target, OpenElementMethod, isMethodCall: true));
            call.Arguments.Add(seqArg);
            call.Arguments.Add(LuaFactory.LiteralExpression(robloxClass));
            return call;
        }

        public IEnumerable<INamedTypeSymbol> ContributeImports(CompilationUnitSyntax syntax, TransformerState state)
        {
            yield break;
        }

        public IEnumerable<INamedTypeSymbol> SuppressImports(CompilationUnitSyntax syntax, TransformerState state)
        {
            // Tags.Frame etc. resolve to ComponentBase shims that never
            // ship as Luau modules — the rewrite above replaces the only
            // call site. Drop their imports so the emitted CS.import
            // doesn't point at a non-existent Plugins.Blazor.Frame.
            if (state.SemanticModel.Compilation is null) yield break;

            foreach (UsingDirectiveSyntax usingDir in syntax.DescendantNodes().OfType<UsingDirectiveSyntax>())
            {
                if (usingDir.Name is null) continue;
                INamespaceSymbol ns = state.SemanticModel.GetSymbolInfo(usingDir.Name).Symbol as INamespaceSymbol;
                if (ns?.ToDisplayString() != TagsNamespace) continue;

                foreach (INamedTypeSymbol shim in ns.GetTypeMembers())
                {
                    yield return shim;
                }
            }
        }

        public void OnUnitTransformed(LuaCompilationUnit unit, CompilationUnitSyntax syntax, TransformerState state)
        {
        }

        public void EmitArtifacts(string outDir, IReadOnlyList<Plugin> plugins, RojoResolver resolver, DiagnosticBag diagnostics)
        {
        }

        private static bool IsTagShim(ITypeSymbol type)
        {
            if (type is null) return false;
            return type.ContainingNamespace?.ToDisplayString() == TagsNamespace;
        }
    }
}
