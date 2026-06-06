// Mirrors PluginExtensionLoader.ImplicitUsingsSource — those global
// usings are injected when the host compiles extension/*.cs in memory
// (legacy fallback path), but a `dotnet build` of this csproj wouldn't
// see them. Declaring them here keeps both compilation modes working
// off the same source file set.
global using System;
global using System.Collections.Generic;
global using System.IO;
global using System.Linq;
global using System.Net.Http;
global using System.Text;
global using System.Threading;
global using System.Threading.Tasks;
global using Microsoft.CodeAnalysis;
global using Microsoft.CodeAnalysis.CSharp;
global using Microsoft.CodeAnalysis.CSharp.Syntax;
global using RobloxCSharp.Common.Diagnostics;
global using RobloxCSharp.Plugins;
global using RobloxCSharp.Rojo;
global using RobloxCSharp.Transformer;
global using RobloxCSharp.Transformer.AST;
global using RobloxCSharp.Transformer.AST.Expressions;
global using RobloxCSharp.Transformer.Extensibility;
global using RobloxCSharp.Transformer.Factory;

// `Microsoft.CodeAnalysis.DiagnosticBag` is an internal Roslyn type; with
// both namespaces imported, the unqualified `DiagnosticBag` would be
// ambiguous and the compiler picks the inaccessible Roslyn one. Pin the
// short name to the framework's public type.
global using DiagnosticBag = RobloxCSharp.Common.Diagnostics.DiagnosticBag;
