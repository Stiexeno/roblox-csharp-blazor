using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using RobloxCSharp.Common.Diagnostics;
using RobloxCSharp.Plugins;
using RobloxCSharp.Rojo;
using RobloxCSharp.Transformer;
using RobloxCSharp.Transformer.AST;
using RobloxCSharp.Transformer.AST.Expressions;
using RobloxCSharp.Transformer.Extensibility;
using RobloxCSharp.Transformer.Factory;

namespace RobloxCSharp.Extensions.Blazor
{
	/// <summary>
	/// Lets users declare @ref fields as the concrete Roblox Instance class
	/// (e.g. <c>private UIScale _scale;</c>) instead of always wrapping in
	/// <see cref="Microsoft.AspNetCore.Components.ElementReference"/>. Razor
	/// emits <c>(__value) =&gt; _field = __value</c> from <c>@ref="_field"</c>;
	/// when LHS is an Instance subclass and RHS is an ElementReference, we
	/// transpile the assignment as <c>self._field = __value.Instance</c> so
	/// the user's typed field receives the underlying Roblox handle directly.
	/// </summary>
	public sealed class BlazorElementReferenceOverride : IRobloxCSharpExtension
	{
		private const string ElementReferenceTypeName = "ElementReference";
		private const string ElementReferenceNamespace = "Microsoft.AspNetCore.Components";
		private const string InstanceTypeName = "Instance";
		private const string InstanceNamespace = "RobloxCSharp.RobloxApi";
		private const string InstanceMember = "Instance";

		public string Name => "Blazor.ElementReferenceOverride";

		public void OnCompile(Compilation compilation, IReadOnlyList<Plugin> plugins, DiagnosticBag diagnostics)
		{
		}

		public LuaNode TryRewrite(SyntaxNode syntax, TransformerState state)
		{
			if (syntax is not AssignmentExpressionSyntax assign) return null;
			if (!assign.IsKind(SyntaxKind.SimpleAssignmentExpression)) return null;

			ISymbol lhsSymbol = state.SemanticModel.GetSymbolInfo(assign.Left).Symbol;
			ITypeSymbol lhsType = TypeOfTarget(lhsSymbol);
			if (!IsInstanceSubclass(lhsType)) return null;

			ITypeSymbol rhsType = state.SemanticModel.GetTypeInfo(assign.Right).Type;
			if (!IsElementReferenceType(rhsType)) return null;

			LuaExpression lhsLua = state.Transform(assign.Left) as LuaExpression;
			LuaExpression rhsLua = state.Transform(assign.Right) as LuaExpression;
			if (lhsLua is null || rhsLua is null) return null;

			LuaExpression unwrapped = LuaFactory.MemberAccess(rhsLua, InstanceMember);
			return LuaFactory.Assignment(SyntaxKind.SimpleAssignmentExpression, lhsLua, unwrapped);
		}

		public IEnumerable<INamedTypeSymbol> ContributeImports(CompilationUnitSyntax syntax, TransformerState state)
		{
			yield break;
		}

		public IEnumerable<INamedTypeSymbol> SuppressImports(CompilationUnitSyntax syntax, TransformerState state)
		{
			yield break;
		}

		public void OnUnitTransformed(LuaCompilationUnit unit, CompilationUnitSyntax syntax, TransformerState state)
		{
		}

		public void EmitArtifacts(string outDir, IReadOnlyList<Plugin> plugins, RojoResolver resolver, DiagnosticBag diagnostics)
		{
		}

		private static ITypeSymbol TypeOfTarget(ISymbol symbol) => symbol switch
		{
			IFieldSymbol f => f.Type,
			IPropertySymbol p => p.Type,
			ILocalSymbol l => l.Type,
			IParameterSymbol pa => pa.Type,
			_ => null,
		};

		private static bool IsInstanceSubclass(ITypeSymbol type)
		{
			INamedTypeSymbol named = type as INamedTypeSymbol;
			while (named is not null)
			{
				if (named.Name == InstanceTypeName
					&& named.ContainingNamespace?.ToDisplayString() == InstanceNamespace)
				{
					return true;
				}
				named = named.BaseType;
			}
			return false;
		}

		private static bool IsElementReferenceType(ITypeSymbol type)
		{
			if (type is null) return false;
			return type.Name == ElementReferenceTypeName
				&& type.ContainingNamespace?.ToDisplayString() == ElementReferenceNamespace;
		}
	}
}
