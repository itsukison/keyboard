# Liquid Glass — Reusable Components & Adoption Notes for Bikey

Source: [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass) + [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views) (Apple Developer Documentation, iOS 26+).

This doc is a curated, opinionated cheat-sheet of the Liquid Glass surface area we will actually use across the Bikey container app. It is *not* a full mirror of Apple's docs — it filters down to the APIs that map directly to screens we already have (`HomeScreen`, `RootContainerView` / `LiquidTabBar`, `ProfileScreen`, `DictionaryScreen`, the onboarding flow).

---

## 1. Mental model

Liquid Glass is a **dynamic material** — not a color, not a blur. It refracts/tints whatever is behind it and reacts to motion and touch. Two practical consequences:

1. **Standard system chrome adopts it automatically.** `NavigationStack`, `TabView`, `.toolbar`, `Form { ... }.formStyle(.grouped)`, `Section`, `Picker`, `Toggle`, `Slider`, sheets, popovers, `.confirmationDialog` — you get glass for free. **Do not** put your own background behind them.
2. **Custom views opt in via `.glassEffect(...)`.** Use sparingly, and *only* for important functional surfaces (primary action bars, floating action capsules, custom toolbars). Decorative glass on cards is explicitly discouraged.

When in doubt: prefer the system component, prefer fewer glass layers, prefer wrapping multiple glass shapes in a `GlassEffectContainer`.

### Hard "don'ts" from Apple

- Don't overuse custom glass — it competes with content.
- Don't put custom backgrounds on controls, nav bars, or tab bars (you defeat the system effect).
- Don't stack multiple `.glassEffect()` views without a `GlassEffectContainer`.
- Don't hard-code bar metrics — let the system size them.
- Don't mix text + icon in the same grouped toolbar item.
- Don't hide a view inside a `ToolbarItem`; hide the `ToolbarItem` itself with `.hidden(_:)`.

### Accessibility floor (must test all three)

- **Reduce Transparency** on — glass falls back to opaque material; verify legibility.
- **Reduce Motion** on — morphing transitions should degrade gracefully.
- **Increase Contrast** + light/dark — both appearance variants.

---

## 2. The reusable SwiftUI surface

These are the APIs we should plan to use repeatedly across the app.

### 2.1 `.glassEffect(_:in:)` — the core modifier

```swift
func glassEffect(_ glass: Glass = .regular, in shape: some Shape = Capsule()) -> some View
```

Default shape is `Capsule()` (matches our current tab bar / banner aesthetic). Pass `in: .rect(cornerRadius:)` or `ConcentricRectangle()` for cards.

```swift
// Pill (default)
Text("Bikey keyboard enabled")
    .padding()
    .glassEffect()

// Rounded rect, custom radius
HeroContent()
    .padding(24)
    .glassEffect(in: .rect(cornerRadius: 28))

// Tinted + interactive (responds to touch / pointer)
ActionButton()
    .glassEffect(.regular.tint(.purple).interactive())
```

**Apply ordering rule.** `.glassEffect` must come **after** all appearance modifiers (padding, frame, foregroundStyle) and **before** layout/position modifiers that move the view.

### 2.2 `Glass` variants

| Variant | Call | When to use |
|---|---|---|
| Regular | `.regular` | Default. Frosted, opaque-ish. Anywhere you'd previously reach for `.ultraThinMaterial`. |
| Tinted | `.regular.tint(.purple)` | Brand-tinted surface (e.g. Bikey purple action capsule). Tint is subtractive — keep saturation high or it disappears. |
| Interactive | `.regular.interactive()` | Adds press/hover response. Use on anything that handles a gesture. |
| Combined | `.regular.tint(.orange).interactive()` | Chain freely. |

There is no `.clear` glass in SwiftUI yet — UIKit has `UIButton.Configuration.clearGlass()` / `prominentClearGlass()` if we ever need it on the keyboard extension side.

### 2.3 `GlassEffectContainer` — the performance + morphing wrapper

```swift
GlassEffectContainer(spacing: 40) {
    HStack(spacing: 40) {
        IconA().glassEffect()
        IconB().glassEffect()
    }
}
```

- **Required** whenever two or more `.glassEffect` views sit near each other. Without it, each glass is rendered independently and the result looks muddy and is slow.
- The `spacing` parameter is the **merge threshold**: any two glass shapes closer than `spacing` blend into one continuous blob. Set it equal to or greater than the layout spacing if you want adjacent items to look like one capsule, smaller if you want them to stay distinct.
- Animating layout changes inside the container produces the signature "liquid morph."

### 2.4 `.glassEffectID(_:in:)` — track identity across structural changes

```swift
@Namespace private var ns

GlassEffectContainer(spacing: 40) {
    HStack {
        IconA()
            .glassEffect()
            .glassEffectID("a", in: ns)

        if isExpanded {
            IconB()
                .glassEffect()
                .glassEffectID("b", in: ns)
        }
    }
}
```

Use this any time a glass element is conditionally inserted/removed inside a container. Without an ID + namespace, the new element materializes; with them, it morphs out of an adjacent shape.

### 2.5 `.glassEffectUnion(id:namespace:)` — merge dynamic siblings

For `ForEach`-generated items that should share one blob even at rest:

```swift
GlassEffectContainer(spacing: 20) {
    HStack(spacing: 20) {
        ForEach(items.indices, id: \.self) { i in
            ItemIcon(items[i])
                .glassEffect()
                .glassEffectUnion(id: items[i].groupID, namespace: ns)
        }
    }
}
```

Items sharing the same `id` render as one continuous glass surface.

### 2.6 `.glassEffectTransition(_:)` — control add/remove animation

| Transition | When to use |
|---|---|
| `.matchedGeometry` (default) | The new/removed glass is within `spacing` of a neighbor — produces the morph. |
| `.materialize` | The glass appears far from any sibling. Falls back to opacity + material crossfade. |

### 2.7 Button styles

```swift
Button("Try demo") { }
    .buttonStyle(.glass)         // Subtle, secondary actions

Button("Create account") { }
    .buttonStyle(.glassProminent) // Primary CTA — fills with accent
```

These automatically apply `.glassEffect`, gesture response, and the right contrast. **Replace** our current custom capsule + gradient buttons with these where possible (the current "Try demo" pill and onboarding "Create account" button are prime candidates).

### 2.8 Concentric shapes

```swift
ConcentricRectangle()   // automatically inherits parent corner radius
.rect(cornerRadius:)    // explicit radius
```

`ConcentricRectangle` is the right primitive for child surfaces inside a glass container (e.g. the inner conversion preview pill inside the hero card) — it stays geometrically concentric with the parent at any radius.

---

## 3. System chrome we should lean on (free glass)

| Container in Bikey | Use this | Notes |
|---|---|---|
| Root tab bar (`LiquidTabBar`) | `TabView` + `.tabBarMinimizeBehavior(.onScrollDown)` (or keep custom + use `.glassEffect`) | The hand-rolled bar is fine but **must** be wrapped in a `GlassEffectContainer` if we add a moving indicator. |
| Search tab inside the tab bar | `Tab(role: .search) { ... }` | System auto-positions it. |
| Nav bars / toolbars on Profile, Dictionary | `NavigationStack` + `.toolbar { ToolbarItem(...) }` | Drop any custom background. Use `Spacer(minLength:)` inside the toolbar to group related items. |
| Hero card on Home | `.backgroundExtensionEffect()` | If we want the background image to bleed under sidebars/edges on iPad. |
| Settings / profile lists | `Form { Section(...) { ... } }.formStyle(.grouped)` | Section headers should be title-case. |
| Modals (sign-in errors, etc.) | `.confirmationDialog(_:isPresented:presenting:actions:)` | Anchor with `presenting:` so iPad shows a glass popover. |

---

## 4. Mapping straight into Bikey screens

Where each API lands in *our* code.

### 4.1 `iOS/Container/RootContainerView.swift` — `LiquidTabBar`

We just removed the lavender selection capsule. Two cleaner paths forward:

- **A — keep the white capsule bar but make it actual glass.**
  Replace `.background(.white.opacity(0.92), in: Capsule())` with `.glassEffect(in: Capsule())` and wrap the `HStack` in a `GlassEffectContainer(spacing: 0)` (spacing 0 because we don't want tabs to merge). Drop the `.shadow` — glass has its own depth.

- **B — switch to native `TabView`.** Gets us tab minimize, search-tab semantics, and proper safe-area handling for free. Bigger refactor; revisit after the visual polish pass.

If/when we want a *selection indicator* back, it should be a child glass shape inside a `GlassEffectContainer`, identified with `.glassEffectID("selection", in: ns)` so the selection morphs between tabs instead of cross-fading.

### 4.2 `iOS/Container/HomeScreen.swift`

- **`HeaderView.StatsPill`** — `.background(.white.opacity(0.76), in: Capsule())` → `.glassEffect(in: Capsule())`. Drop the shadow.
- **`PowerToggle`** — replace the gradient capsule with `Toggle(isOn:)` + a `.toggleStyle(.switch)`, or keep custom and wrap with `.glassEffect(.regular.tint(.purple).interactive(), in: Capsule())`.
- **`KeyboardEnabledBanner`** — `.background(AppColor.paleLavender.opacity(0.72), in: RoundedRectangle(...))` → `.glassEffect(.regular.tint(AppColor.lavender), in: .rect(cornerRadius: 30))`.
- **`HeroCard` "Try demo" pill** — `.background(.black, in: Capsule())` → `Button { } label: { ... }.buttonStyle(.glassProminent)` with `.tint(.black)` (or our purple). The whole hero card itself should stay solid imagery — glass on top of the background image is fine *only* for the inner `ConversionPreviewPill`, which is already a candidate for `.glassEffect(in: ConcentricRectangle())`.
- **`RecentConversionCard`** — `.background(.white.opacity(0.9), in: RoundedRectangle(...))`. Cards-on-list is exactly the case Apple says *not* to overuse glass on. Keep these as solid white surfaces. **Do not glassify list rows.**

Wrap the whole header row (`AppIconTile` + `StatsPill` + `PowerToggle`) in a `GlassEffectContainer(spacing: 14)` so the three pieces share one continuous render pass.

### 4.3 `iOS/Container/RootContainerView.swift` — onboarding

- **`OnboardingPrimaryButtonLabel`** — replace the custom `LinearGradient` capsule with `Button(...).buttonStyle(.glassProminent).tint(AppColor.purple)`. We lose nothing visually and gain the press response.
- **`WelcomePreviewCard`** — leave as a solid white card (same reasoning as `RecentConversionCard`).

### 4.4 `ProfileScreen` and `DictionaryScreen`

Both should be `NavigationStack { List/Form { ... } }`. Drop any custom row background, let `.formStyle(.grouped)` + `Section` provide the chrome.

---

## 5. Performance + accessibility checklist

Before shipping any glass change:

- [ ] All adjacent glass shapes are inside the same `GlassEffectContainer`.
- [ ] No `.shadow` on a view that also has `.glassEffect` (double depth).
- [ ] No custom `.background(material)` competing with the system on `NavigationStack` / `TabView` / `.toolbar`.
- [ ] Verified in Simulator with **Settings → Accessibility → Display & Text Size → Reduce Transparency** → ON.
- [ ] Verified with **Reduce Motion** ON (no jarring morph fallbacks).
- [ ] Verified light + dark appearance.
- [ ] No more than ~3 distinct glass containers visible on a single screen at once (Apple's own guidance).

---

## 6. APIs we have **no** use for right now

Listed so future-us doesn't waste time reading the same Apple page twice:

- `NavigationSplitView`, `inspector(isPresented:)`, `UISplitViewController.Column.inspector` — iPad-only multi-column; Bikey is phone-first.
- `UIBackgroundExtensionView` / `.backgroundExtensionEffect()` — only useful with a sidebar.
- `safeAreaBar(edge:alignment:spacing:content:)` — interesting for a future "live conversion suggestion" bar above the keyboard preview; park it.
- `scrollEdgeEffectStyle(_:for:)` — for fade-under-bar effects, mostly automatic.
- AppKit `NSGlassEffectView` / `NSBackgroundExtensionView` — Mac Catalyst only.
- `UIDesignRequiresCompatibility` Info.plist key — opt-out flag for the old appearance. We want the new appearance, so leave unset.

---

## 7. Next step

Once this doc is reviewed, work order for the actual application pass:

1. `LiquidTabBar` → real `.glassEffect` + `GlassEffectContainer`. (smallest, highest-visibility change)
2. `OnboardingPrimaryButtonLabel` → `.buttonStyle(.glassProminent)`.
3. `HeaderView` (stats pill + power toggle) → glass capsules in a shared container.
4. `KeyboardEnabledBanner` → tinted glass rounded rect.
5. `HeroCard` inner preview pill → glass; "Try demo" → `.glassProminent`.
6. `ProfileScreen` / `DictionaryScreen` → strip custom backgrounds, lean on `Form` + `Section`.

Each step is independently reviewable in the simulator.
