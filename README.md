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
| `AddElementReferenceCapture(seq, action)` | Captures the underlying Roblox Instance into an `ElementReference`. Razor's `@ref="field"` emits this. |

Attribute names starting with `on` (case-insensitive) are treated as events. Curated mappings include `onclick` → `MouseButton1Click`, `onmouseenter` → `MouseEnter`, `onfocus` → `Focused`, etc. Names like `onMouseWheelForward` pass through verbatim as signal names, so any Roblox event is reachable.

### `Renderer`

| Method | Purpose |
|---|---|
| `Renderer.Mount<TComponent>(parentInstance)` | Instantiate and render `TComponent` under a Roblox Instance. Returns a `RenderHandle`. |
| `handle.Unmount()` | Tear down the rendered tree and disconnect all event subscriptions. |

### `[Parameter]`

Marks a public property as a component parameter. The parent component (or `.razor` markup) writes these on each render before `OnParametersSet` fires.

### `ElementReference` and `@ref`

Capture the underlying Roblox Instance from a rendered element and reach it imperatively — for TweenService animations, physics constraints, focus management, or anything else that needs a handle the declarative tree doesn't expose:

```razor
@using Microsoft.AspNetCore.Components

<Frame @ref="_panel"
       Size="@(new UDim2(0, 200, 0, 80))"
       BackgroundColor3="@(new Color3(0.15f, 0.15f, 0.18f))" />

@code {
    private ElementReference _panel;

    protected override void OnAfterRender(bool firstRender)
    {
        if (!firstRender) return;
        TweenService.Create(
            _panel.Instance,
            new TweenInfo(0.6f, EasingStyle.Back, EasingDirection.Out),
            new { Position = new UDim2(0.5f, -100, 0.5f, -40) }
        ).Play();
    }
}
```

The capture fires after the Reconciler materializes (or reuses) the Instance, so `_panel.Instance` is set before `OnAfterRender` runs. On the first render it points at a freshly-created Instance; on subsequent renders that preserve the same element, it still points at the same Instance (the reconciler keeps it alive), so in-flight tweens survive state changes.

## Animations

Two paths, complementary:

**Declarative.** Tweenable properties (`Position`, `Size`, `BackgroundColor3`, `Rotation`, `Transparency`, `Scale`, etc.) tween automatically when their value changes across renders. Bind to state and call `StateHasChanged`:

```razor
<Frame Size="@(_expanded ? Big : Small)"
       BackgroundColor3="@(_hovered ? Highlight : Base)" />
```

A re-render where only `_expanded` flipped does **not** rebuild the Frame — the Reconciler diffs attribute values, only writes the ones that changed, and routes those writes through `TweenService:Create` (default `TweenInfo(0.18, Quad, Out)`). Setting a property to the same value is a no-op; consecutive renders that change the same property cancel the in-flight tween and start a new one toward the latest target.

**Imperative.** For custom easing, looped tweens, or anything outside the eight-or-so curated tweenable properties, grab an `ElementReference` (`@ref`) and call `TweenService` directly inside `OnAfterRender`. Use a `firstRender` guard to wire one-shot mount animations; track signal connections on the component if you need to detach them on unmount.

## How it works

The Razor compiler — and hand-written `BuildRenderTree` overrides — emit a flat sequence of "frames" via `RenderTreeBuilder`: open-element, attributes, content, close-element, ref-capture. The Luau runtime walks that sequence into a tree and reconciles it against the previous render's tree by walking child arrays in parallel, matching positions by `(kind, element name, component type)`. Matches reuse the existing Roblox Instance and diff attributes (tween-on-write for animatable properties; reuse the existing signal connection if the handler value is referentially unchanged). Mismatches destroy the old subtree and create the new one at that position. Component frames recurse: each child component owns its own `RenderHandle` and reconciler state, so a parent re-render forwards parameters and lets the child diff its own subtree.

`Renderer.Mount` is the public entry. It constructs the component, attaches a `RenderHandle` pointing at your parent Instance, and drives the first render. The handle can be torn down with `Unmount` for hot reload or test cleanup.

## What's not in v1

- **Async lifecycle hooks.** `OnInitializedAsync` / `OnParametersSetAsync` / `OnAfterRenderAsync` aren't exposed; the transpiler's async story is its own roadmap item.
- **`[Inject]` integration with the DI plugin.** The attribute is declared so .razor files using it will compile, but parameter injection at mount time isn't wired yet — components inject services through their constructor for now, same as any DI-resolved class.
- **Component refs.** `@ref` on a child component (`AddComponentReferenceCapture`) isn't wired yet; only element refs work.
- **`@key`, `@bind`.** Not in v1; each needs its own runtime support.
- **Batched re-renders.** `StateHasChanged` re-renders synchronously per call.

## License

[MIT](LICENSE).
