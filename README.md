# roblox-csharp-blazor

Blazor-style UI for Roblox, packaged as a [roblox-csharp](https://github.com/Stiexeno/roblox-csharp) plugin. Write components as C# classes (or, eventually, `.razor` files), describe UI declaratively, and let the runtime reconcile the result into Roblox Instance trees — so your UI lives in source control alongside the rest of your game code.

## Install

From your roblox-csharp project root:

```sh
roblox-csharp plugin add Stiexeno/roblox-csharp-blazor
```

That drops the plugin into `plugins/Blazor/`. Recompile (`roblox-csharp` or `roblox-csharp dev`) and the runtime mounts at `ReplicatedStorage.Plugins.Blazor`.

## Quick start

The same component, written two ways. Pick whichever fits your taste — both produce identical Luau.

### `.razor` (preferred — IDE intellisense, less boilerplate)

```razor
@using Microsoft.AspNetCore.Components
@using Microsoft.AspNetCore.Components.Rendering

<TextButton Size="@(new UDim2(0, 200, 0, 50))"
            Position="@(new UDim2(0.5f, -100, 0.5f, -25))"
            BackgroundColor3="@(new Color3(0.2f, 0.4f, 0.8f))"
            TextColor3="@(new Color3(1f, 1f, 1f))"
            Text="@($"{Label}: {_count}")"
            @onclick="OnClick">
</TextButton>

@code {
    [Parameter] public string Label { get; set; } = "Clicks";

    private int _count = 0;

    private void OnClick()
    {
        _count++;
        StateHasChanged();
    }
}
```

> **Event handlers.** `@onclick`, `@onmouseenter`, `@onfocus`, and any `@onXxx` directive work transparently on Roblox UI tags — the transpiler rewrites Razor's literal-string fallback on unknown elements into a proper `EventCallback.Factory.Create(this, MethodName)` wiring, then the runtime maps the event name (`onclick` → `MouseButton1Click`, etc.) to the matching Roblox signal. The explicit `onclick="@(EventCallback.Factory.Create(this, Method))"` form still works if you want it.

### Hand-written C#

```csharp
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Rendering;
using Blazor;

public class Counter : ComponentBase
{
    [Parameter] public string Label { get; set; } = "Clicks";

    private int _count = 0;

    protected override void BuildRenderTree(RenderTreeBuilder __builder)
    {
        __builder.OpenElement(0, "TextButton");
        __builder.AddAttribute(1, "Size", new UDim2(0, 200, 0, 50));
        __builder.AddAttribute(2, "Position", new UDim2(0.5f, -100, 0.5f, -25));
        __builder.AddAttribute(3, "Text", $"{Label}: {_count}");
        __builder.AddAttribute(4, "onclick", EventCallback.Factory.Create(this, OnClick));
        __builder.CloseElement();
    }

    private void OnClick()
    {
        _count++;
        StateHasChanged();
    }
}
```

Mount from a client bootstrap (works naturally with the DI plugin's `ClientInstaller`):

```csharp
public class UIInstaller : ClientInstaller
{
    public UIInstaller(Container container) : base(container) { }

    public override void InstallBindings()
    {
        var screen = new Instance("ScreenGui");
        screen.Parent = LocalPlayer.PlayerGui;
        Renderer.Mount<Counter>(screen);
    }
}
```

## API surface

### `ComponentBase`

| Member | Purpose |
|---|---|
| `BuildRenderTree(RenderTreeBuilder)` | Override to describe the component's UI. |
| `StateHasChanged()` | Trigger a re-render after state changes. |
| `OnInitialized()` | Lifecycle hook; called once before the first render. |
| `OnParametersSet()` | Lifecycle hook; called every render after parameters apply. |
| `OnAfterRender(firstRender)` | Lifecycle hook; called after each render. |

### `RenderTreeBuilder`

| Method | Purpose |
|---|---|
| `OpenElement(seq, name)` / `CloseElement()` | Open/close a Roblox Instance region. `name` is the class name (`Frame`, `TextLabel`, `ImageButton`, etc.). |
| `OpenComponent<T>(seq)` / `CloseComponent()` | Open/close a child component region. Attributes between the calls become its parameters. |
| `AddAttribute(seq, name, value)` | Set a property or wire an event on the current open region. |
| `AddContent(seq, content)` | Write text content (sets `.Text` if available, else creates a `TextLabel` child). |

Attribute names starting with `on` (case-insensitive) are treated as events. Curated mappings include `onclick` → `MouseButton1Click`, `onmouseenter` → `MouseEnter`, `onfocus` → `Focused`, etc. Names like `onMouseWheelForward` pass through verbatim as signal names, so any Roblox event is reachable.

### `Renderer`

| Method | Purpose |
|---|---|
| `Renderer.Mount<TComponent>(parentInstance)` | Instantiate and render `TComponent` under a Roblox Instance. Returns a `RenderHandle`. |
| `handle.Unmount()` | Tear down the rendered tree and disconnect all event subscriptions. |

### `[Parameter]`

Marks a public property as a component parameter. The parent component (or `.razor` markup, once SDK support lands) writes these on each render before `OnParametersSet` fires.

## How it works

The Razor compiler — and hand-written `BuildRenderTree` overrides — emit a flat sequence of "frames" via `RenderTreeBuilder`: open-element, attributes, content, close-element. The Luau runtime walks that sequence as a stack and produces a Roblox Instance tree under the parent you mounted into.

Events follow the same path: an attribute frame whose name starts with `on` is connected to the matching Roblox signal (`MouseButton1Click`, `Focused`, etc.) and disconnected on the next render. Component frames recurse — `OpenComponent<MyChild>` accumulates parameters, then on `CloseComponent` the child is mounted with its own `RenderHandle`, so its `StateHasChanged` only re-renders its own subtree.

`Renderer.Mount` is the public entry. It constructs the component, attaches a `RenderHandle` pointing at your parent Instance, and drives the first render. The handle can be torn down with `Unmount` for hot reload or test cleanup.

## What's not in v1

- **Positional diffing.** v1 tears down and rebuilds the Instance tree on every render. Correct, easy to reason about, but wasteful for large UIs. The real Blazor diff (match by sequence number, replace mismatched subtrees) is planned for v1.1 without any change to the public API.
- **Async lifecycle hooks.** `OnInitializedAsync` / `OnParametersSetAsync` / `OnAfterRenderAsync` aren't exposed; the transpiler's async story is its own roadmap item.
- **`[Inject]` integration with the DI plugin.** The attribute is declared so .razor files using it will compile, but parameter injection at mount time isn't wired yet — components inject services through their constructor for now, same as any DI-resolved class.
- **`ElementReference`, `@ref`, `@key`, `@bind`.** Not in v1; would each need their own runtime support.
- **Batched re-renders.** `StateHasChanged` re-renders synchronously per call.

## License

[MIT](LICENSE).
