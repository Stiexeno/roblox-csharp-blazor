using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using RobloxCSharp;
using RobloxCSharp.Transformer;
using RobloxCSharp.Transformer.Extensibility;

namespace Blazor.Tests
{
	internal static class TestHarness
	{
		public const string Stubs = @"
namespace RobloxCSharp.RobloxApi
{
	public class Instance { }
	public class GuiBase2d : Instance { }
	public class GuiObject : GuiBase2d { }
	public class Frame : GuiObject { }
	public class TextLabel : GuiObject { }
	public class UIScale : Instance { }
}

namespace Microsoft.AspNetCore.Components
{
	public struct ElementReference
	{
		public RobloxCSharp.RobloxApi.Instance Instance { get; }
		public ElementReference(RobloxCSharp.RobloxApi.Instance instance) { Instance = instance; }
	}
}
";

		public static (TransformerState State, CompilationUnitSyntax Root) Compile(string userSource)
		{
			SyntaxTree userTree = CSharpSyntaxTree.ParseText(userSource);
			SyntaxTree stubsTree = CSharpSyntaxTree.ParseText(Stubs);
			CSharpCompilation compilation = CompilationFactory.Create("Anonymous", userTree, stubsTree);
			CSharpCompilationContext context = new(userTree, compilation);
			TransformerState state = new(context);
			return (state, (CompilationUnitSyntax)userTree.GetRoot());
		}

		public static AssignmentExpressionSyntax FirstAssignment(CompilationUnitSyntax root)
		{
			foreach (SyntaxNode node in root.DescendantNodes())
			{
				if (node is AssignmentExpressionSyntax assign) return assign;
			}
			throw new InvalidOperationException("No assignment found in source.");
		}
	}
}
