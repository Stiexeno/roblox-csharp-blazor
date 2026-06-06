using Microsoft.AspNetCore.Components;

// Razor's HTML schema flags PascalCase tag names (Frame, IFrame, Form,
// …) as obsolete HTML elements when no matching IComponent type is in
// scope. To make Razor — and Rider's Razor-aware editor — recognize
// these as Roblox UI classes instead, we declare empty ComponentBase
// shims with the same names and pull them into .razor files via
// `_Imports.razor`.
//
// The shims have no behaviour of their own; their default (empty)
// BuildRenderTree never runs. The Blazor plugin's transpiler extension
// (BlazorTagElementOverride) rewrites the Razor-emitted
// `OpenComponent<Tags.Frame>` calls to `OpenElement("Frame")` during
// lowering, so the runtime emits the same Roblox Instance tree as
// before — no extra component layer.
namespace RobloxCSharp.Blazor.Tags
{
    // Alias for the Roblox `Frame` UI class. Razor — and Rider's HTML
    // inspector — treats a `<Frame>` tag as the obsolete HTML <frame>
    // element and styles it strikethrough; the IntelliJ-platform
    // schema check that drives that styling isn't configurable per
    // project. Using a non-colliding name (Rect) sidesteps the whole
    // issue, and BlazorTagElementOverride remaps it back to "Frame"
    // when emitting Luau so the runtime still creates a Roblox Frame.
    public class Rect : ComponentBase { }
    public class ScrollingFrame : ComponentBase { }
    public class TextLabel : ComponentBase { }
    public class TextButton : ComponentBase { }
    public class TextBox : ComponentBase { }
    public class ImageLabel : ComponentBase { }
    public class ImageButton : ComponentBase { }
    public class VideoFrame : ComponentBase { }
    public class ViewportFrame : ComponentBase { }
    public class CanvasGroup : ComponentBase { }

    public class ScreenGui : ComponentBase { }
    public class BillboardGui : ComponentBase { }
    public class SurfaceGui : ComponentBase { }

    public class UICorner : ComponentBase { }
    public class UIStroke : ComponentBase { }
    public class UIPadding : ComponentBase { }
    public class UIGradient : ComponentBase { }
    public class UIScale : ComponentBase { }
    public class UISizeConstraint : ComponentBase { }
    public class UIAspectRatioConstraint : ComponentBase { }
    public class UITextSizeConstraint : ComponentBase { }
    public class UIListLayout : ComponentBase { }
    public class UIGridLayout : ComponentBase { }
    public class UIPageLayout : ComponentBase { }
    public class UITableLayout : ComponentBase { }
    public class UIFlexItem : ComponentBase { }
}
