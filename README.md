# roblox-csharp-blazor

Blazor-style UI for Roblox: write components as `.razor` files or C# classes, and a Luau runtime reconciles the render tree into Roblox Instances.

## Install

```sh
roblox-csharp plugin add Stiexeno/roblox-csharp-blazor
```

Drops into `plugins/Blazor/`; the runtime mounts at `ReplicatedStorage.Plugins.Blazor`.

## Requirements

- roblox-csharp **0.1.0-alpha.52+** (declared as `minTranspilerVersion` in the manifest; loads the prebuilt `extension.dll`).
- **RobloxApi plugin** — `ElementReference.Instance` and typed `@ref` fields are `RobloxCSharp.RobloxApi.Instance` types.
- **DI plugin** — `Renderer.Mount` requires an `IInstantiator` (`DependencyInjection`); components are constructed through it so ctor injection works.

## Quick start

```razor
@using Microsoft.AspNetCore.Components

<TextButton Size="@(new UDim2(0, 200, 0, 50))"
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

Hand-written `BuildRenderTree(RenderTreeBuilder)` overrides produce the same frames; `OpenElement(seq, "TextButton")` / `AddAttribute` / `CloseElement`.

Mount from client code (instantiator ctor-injected via the DI plugin):

```csharp
var screen = new Instance("ScreenGui");
screen.Parent = LocalPlayer.PlayerGui;
RenderHandle handle = Renderer.Mount<Counter>(screen, _instantiator);
// later: handle.Unmount();
```

## API surface

### `ComponentBase`

| Member | Purpose |
|---|---|
| `BuildRenderTree(RenderTreeBuilder)` | Override to describe UI. |
| `StateHasChanged()` | Re-render synchronously. No-op before mount or inside a render. |
| `OnInitialized()` | Once, before the first render. |
| `OnParametersSet()` | Every render (including self-triggered `StateHasChanged` renders — diverges from Blazor, which only calls it on parameter writes). |
| `OnAfterRender(firstRender)` | After each render. |

### `RenderTreeBuilder`

`OpenElement` / `CloseElement`, `OpenComponent<T>` / `CloseComponent`, `AddAttribute`, `AddContent`, `AddMarkupContent` (whitespace-only content is dropped), `AddComponentParameter` (alias of `AddAttribute`), `AddElementReferenceCapture`.

- Element names go to `Instance.new` verbatim.
- Curated event mappings (case-insensitive): `onclick`→`MouseButton1Click`, `onrightclick`, `onmousedown`/`onmouseup`, `onmouseenter`/`onmouseleave`, `onactivated`, `onfocus`→`Focused`, `onblur`→`FocusLost`, `oninputbegan`/`oninputended`. Beyond those, `on` + an uppercase letter passes through as a literal signal name (`onMouseWheelForward` → `MouseWheelForward`).
- Other attribute names are written as Roblox properties verbatim.

### `Renderer` / `RenderHandle`

| Method | Purpose |
|---|---|
| `Renderer.Mount<TComponent>(parentInstance, instantiator)` | Construct via the instantiator, render under `parentInstance`, return a `RenderHandle`. |
| `handle.Unmount()` | Destroy the rendered Instances, disconnect render-wired events, and detach the component — `StateHasChanged` after unmount is a no-op. |

### `EventCallback`

`[Parameter] public EventCallback OnSomething { get; set; }` on a child, invoked via `OnSomething.InvokeAsync()` / `InvokeAsync(arg)`; the parent wires it with `@onsomething="Handler"` or `EventCallback.Factory.Create(this, Handler)`. Callbacks are cached per (receiver, method), so the same handler passed on consecutive renders is the same value — event connections are reused instead of churning each re-render.

### Razor tag shims

PascalCase Roblox UI tags (`TextButton`, `TextLabel`, `ScrollingFrame`, `ImageButton`, `UICorner`, `UIListLayout`, …) are declared as empty component shims in `RobloxCSharp.Blazor.Tags`; the transpiler extension rewrites `OpenComponent<Tags.X>` back to `OpenElement("X")`, so no component layer exists at runtime. Use `<Rect>` instead of `<Frame>` to dodge Rider's obsolete-HTML strikethrough — it renders a Roblox `Frame`. A plain `<Frame>` tag still works via Razor's unknown-element fallback.

`@onclick="Method"` on these tags is rewritten by the transpiler into `EventCallback.Factory.Create(this, Method)`; the explicit form also works.

### `ElementReference` and `@ref`

`@ref="_field"` captures the backing Instance after each render. Two field shapes:

- `private ElementReference _panel;` — read `_panel.Instance` in `OnAfterRender`.
- A concrete Instance class (`private UIScale _scale;`) — the `BlazorElementReferenceOverride` extension unwraps `.Instance` during lowering, so the field holds the typed Roblox handle directly.

## Reconciliation and animation

Diffing is **positional** per child array, matched by kind + element name / component type; there is no `@key`. Reordering children replaces the moved subtrees. Matched elements reuse their Instance and only changed attributes are written; tweenable properties (`Position`, `Size`, `BackgroundColor3`, `Rotation`, transparencies, `Scale`, `Thickness`, …) animate via `TweenService` (`TweenInfo(0.18, Quad, Out)`), with in-flight tweens cancelled when the target changes again. First-mount writes are instant. Child components own their subtree: a parent re-render forwards parameters and the child diffs locally.

Event connections are reused when the attribute value is referentially identical across renders — method-group handlers qualify via the `EventCallback` cache. Inline lambdas (`@onclick="() => ..."`) are a fresh value each render and still reconnect.

## Not in v1

- **Async lifecycle hooks** (`OnInitializedAsync` etc.).
- **`[Inject]`** — declared so `.razor` files compile; not wired. Use ctor injection.
- **Component refs** (`@ref` on a child component) — silently dropped.
- **`@key`, `@bind`.**
- **Batched re-renders** — every `StateHasChanged` renders synchronously.
- **No dispose hook** — connections you wire manually in `OnAfterRender` must be cleaned up yourself; `Unmount` only disconnects render-wired events.

## License

[MIT](LICENSE).
