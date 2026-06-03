using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using RobloxCSharp;
using RobloxCSharp.Extensions.Blazor;
using RobloxCSharp.Transformer;
using RobloxCSharp.Transformer.AST;
using RobloxCSharp.Transformer.AST.Expressions;

namespace Blazor.Tests
{
	public class BlazorElementReferenceOverrideTests
	{
		private static (TransformerState State, AssignmentExpressionSyntax Assign) Setup(string body)
		{
			string source = $@"
using RobloxCSharp.RobloxApi;
using Microsoft.AspNetCore.Components;

public class Test
{{
	{body}
}}
";
			(TransformerState state, CompilationUnitSyntax root) = TestHarness.Compile(source);
			AssignmentExpressionSyntax assign = TestHarness.FirstAssignment(root);
			return (state, assign);
		}

		private static BlazorElementReferenceOverride Subject => new();

		private static void AssertUnwraps(LuaNode result, string expectedRhsRoot)
		{
			LuaAssignmentExpression assign = Assert.IsType<LuaAssignmentExpression>(result);
			LuaMemberAccessExpression access = Assert.IsType<LuaMemberAccessExpression>(assign.Right);
			Assert.Equal("Instance", access.MemberName);
			LuaIdentifier rhsRoot = Assert.IsType<LuaIdentifier>(access.Target);
			Assert.Equal(expectedRhsRoot, rhsRoot.Name);
		}

		[Fact]
		public void FieldTypedAsInstanceSubclass_UnwrapsInstance()
		{
			(TransformerState state, AssignmentExpressionSyntax assign) = Setup(@"
				private UIScale _scale;
				void M(ElementReference er) { _scale = er; }");

			LuaNode result = Subject.TryRewrite(assign, state);

			AssertUnwraps(result, expectedRhsRoot: "er");
		}

		[Fact]
		public void FieldTypedAsDeepInstanceSubclass_UnwrapsInstance()
		{
			(TransformerState state, AssignmentExpressionSyntax assign) = Setup(@"
				private Frame _frame;
				void M(ElementReference er) { _frame = er; }");

			LuaNode result = Subject.TryRewrite(assign, state);

			AssertUnwraps(result, expectedRhsRoot: "er");
		}

		[Fact]
		public void FieldTypedAsInstanceDirectly_UnwrapsInstance()
		{
			(TransformerState state, AssignmentExpressionSyntax assign) = Setup(@"
				private Instance _inst;
				void M(ElementReference er) { _inst = er; }");

			LuaNode result = Subject.TryRewrite(assign, state);

			AssertUnwraps(result, expectedRhsRoot: "er");
		}

		[Fact]
		public void PropertyTypedAsInstanceSubclass_UnwrapsInstance()
		{
			(TransformerState state, AssignmentExpressionSyntax assign) = Setup(@"
				public UIScale Scale { get; set; }
				void M(ElementReference er) { Scale = er; }");

			LuaNode result = Subject.TryRewrite(assign, state);

			AssertUnwraps(result, expectedRhsRoot: "er");
		}

		[Fact]
		public void LocalTypedAsInstanceSubclass_UnwrapsInstance()
		{
			(TransformerState state, AssignmentExpressionSyntax assign) = Setup(@"
				void M(ElementReference er) { UIScale local = null; local = er; }");

			LuaNode result = Subject.TryRewrite(assign, state);

			AssertUnwraps(result, expectedRhsRoot: "er");
		}

		[Fact]
		public void RefCapturedFromLambdaBody_StillUnwraps()
		{
			(TransformerState state, AssignmentExpressionSyntax assign) = Setup(@"
				private UIScale _scale;
				void M() {
					System.Action<ElementReference> capture = val => _scale = val;
				}");

			LuaNode result = Subject.TryRewrite(assign, state);

			AssertUnwraps(result, expectedRhsRoot: "val");
		}

		[Fact]
		public void ElementReferenceLhs_DoesNotRewrite()
		{
			(TransformerState state, AssignmentExpressionSyntax assign) = Setup(@"
				private ElementReference _ref;
				void M(ElementReference er) { _ref = er; }");

			LuaNode result = Subject.TryRewrite(assign, state);

			Assert.Null(result);
		}

		[Fact]
		public void NonInstanceLhs_DoesNotRewrite()
		{
			(TransformerState state, AssignmentExpressionSyntax assign) = Setup(@"
				private string _s;
				void M(ElementReference er) { _s = (string)(object)er; }");

			LuaNode result = Subject.TryRewrite(assign, state);

			Assert.Null(result);
		}

		[Fact]
		public void RhsNotElementReference_DoesNotRewrite()
		{
			(TransformerState state, AssignmentExpressionSyntax assign) = Setup(@"
				private UIScale _scale;
				void M(UIScale other) { _scale = other; }");

			LuaNode result = Subject.TryRewrite(assign, state);

			Assert.Null(result);
		}

		[Fact]
		public void CompoundAssignment_DoesNotRewrite()
		{
			(TransformerState state, AssignmentExpressionSyntax assign) = Setup(@"
				private int _count;
				void M() { _count += 1; }");

			LuaNode result = Subject.TryRewrite(assign, state);

			Assert.Null(result);
		}

		[Fact]
		public void NonAssignmentNode_DoesNotRewrite()
		{
			(TransformerState state, AssignmentExpressionSyntax _) = Setup(@"
				private UIScale _scale;
				void M(ElementReference er) { _scale = er; }");

			// Pass a non-assignment node — TryRewrite must return null silently.
			SyntaxNode someOtherNode = ((Microsoft.CodeAnalysis.SyntaxNode)state.SemanticModel.SyntaxTree.GetRoot()).DescendantNodes()
				.OfType<MethodDeclarationSyntax>().First();

			LuaNode result = Subject.TryRewrite(someOtherNode, state);

			Assert.Null(result);
		}

		[Fact]
		public void IntegrationViaDispatcher_LowersToUnwrappedAssignment()
		{
			(TransformerState _, AssignmentExpressionSyntax assign) = Setup(@"
				private UIScale _scale;
				void M(ElementReference er) { _scale = er; }");

			TransformerState stateWithExtension = WithExtension(assign);
			LuaNode result = stateWithExtension.Transform(assign);

			AssertUnwraps(result, expectedRhsRoot: "er");
		}

		[Fact]
		public void IntegrationViaDispatcher_WithoutExtension_DoesNotUnwrap()
		{
			(TransformerState state, AssignmentExpressionSyntax assign) = Setup(@"
				private UIScale _scale;
				void M(ElementReference er) { _scale = er; }");

			LuaNode result = state.Transform(assign);

			LuaAssignmentExpression a = Assert.IsType<LuaAssignmentExpression>(result);
			Assert.IsNotType<LuaMemberAccessExpression>(a.Right);
		}

		private static TransformerState WithExtension(SyntaxNode node)
		{
			SyntaxTree tree = node.SyntaxTree;
			SyntaxTree stubsTree = Microsoft.CodeAnalysis.CSharp.CSharpSyntaxTree.ParseText(TestHarness.Stubs);
			Microsoft.CodeAnalysis.CSharp.CSharpCompilation compilation =
				CompilationFactory.Create("Anonymous", tree, stubsTree);
			CSharpCompilationContext context = new(tree, compilation);
			return new TransformerState(
				context,
				rojoResolver: null,
				pathTranslator: null,
				diagnostics: null,
				pluginBindings: null,
				extensions: new RobloxCSharp.Transformer.Extensibility.IRobloxCSharpExtension[] { Subject });
		}
	}
}
