# Bikey Design System

This document defines the visual direction for the Bikey iOS container app. The target is a premium, quiet, modern Apple-style product inspired by the attached Willow references: soft photographic gradients, restrained typography, rounded glass chrome, high whitespace discipline, and focused task surfaces. The design should feel native to iOS 26+ Liquid Glass while staying practical for a Japanese-English keyboard companion app.

The current home and profile screens are the closest existing references in this repo. Other screens should be redesigned around this document rather than preserving their current look.

## North Star

Bikey should feel like a small, elegant system utility with a personal productivity layer. The interface should be calm, tactile, and light. It should not feel like a generic SaaS dashboard, a marketing landing page, or a colorful language-learning app.

The best reference qualities from the screenshots are:

- Tall phone-first composition with generous top and bottom safe-area breathing room.
- Soft lavender-gray photographic backgrounds with subtle noise, blur, and depth.
- White and near-white cards floating over a warm off-white app background.
- Pill-shaped Liquid Glass controls for primary actions, tab bars, stat counters, toggles, and icon buttons.
- Sparse typography using clean default SF Pro system fonts, mostly regular weight, with emphasis from size and spacing rather than heavy bold text.
- Compact dashboards where every element has a job.
- Bottom sheets with dimmed background, large rounded top corners, and a clear grab handle.
- A restrained monochrome core, with purple used only as brand tint and state accent.

## Visual Principles

### 1. Phone-Native, Not Web-Native

Every screen should be designed as an iPhone surface first. Avoid desktop-style panels, large marketing hero sections, dense tables, or explanatory blocks. Users should immediately land in the working experience.

Screens should use:

- A single primary content column.
- Horizontal insets of 20-24 pt.
- One floating bottom tab bar or one bottom CTA region, never both fighting for attention.
- Safe-area aware spacing rather than fixed full-screen measurements.
- Scroll views only where content genuinely exceeds the viewport.

### 2. Glass Is Chrome, Not Content

Liquid Glass should be used for controls and navigation chrome, not for every card. The premium look comes from contrast between solid content cards and glass controls.

Use Liquid Glass for:

- Bottom tab bar.
- Header stat pills.
- Toggle capsules.
- Floating icon buttons.
- Primary/secondary action pills.
- Modal handles and small toolbar controls.
- Small overlay pills on image or gradient backgrounds.

Avoid Liquid Glass for:

- Long text content cards.
- Repeated list rows.
- Transcript/conversion history cards.
- Dictionary entries.
- Settings rows.

For repeated content, use solid white or near-white rounded surfaces with very soft shadows.

### 3. Soft Depth, No Heavy Decoration

Depth should come from material, translucency, scale, and subtle shadow. Do not use decorative blobs, generic gradients, or ornamental icon panels. Background imagery should feel like the blurred lavender screenshots: ambient but specific to the brand.

Use:

- Off-white base background.
- Lavender-gray ambient image/gradient areas.
- Subtle grain/noise if available in bitmap assets.
- Shadows under solid cards at 3-8 percent black opacity.
- No hard borders except hairline dividers inside white cards.

Avoid:

- Bright purple pages.
- One-note purple screens.
- Large gradient-only backgrounds.
- Nested cards.
- Heavy drop shadows.
- Oversized feature explanation text.

## Color System

Use a warm neutral base with purple as an accent, not as the dominant theme.

```swift
enum BikeyColor {
    static let canvas = Color(red: 0.984, green: 0.981, blue: 0.976)
    static let surface = Color.white.opacity(0.92)
    static let elevatedSurface = Color.white.opacity(0.96)
    static let ink = Color(red: 0.129, green: 0.129, blue: 0.155)
    static let secondaryInk = Color(red: 0.469, green: 0.462, blue: 0.522)
    static let tertiaryInk = Color(red: 0.636, green: 0.630, blue: 0.735)
    static let rule = Color(red: 0.805, green: 0.804, blue: 0.803)
    static let purple = Color(red: 0.341, green: 0.258, blue: 0.656)
    static let purpleSoft = Color(red: 0.917, green: 0.900, blue: 0.973)
    static let lavenderMist = Color(red: 0.950, green: 0.937, blue: 0.986)
    static let charcoalAction = Color(red: 0.151, green: 0.152, blue: 0.187)
}
```

Color rules:

- Main background: `canvas`.
- Main text: `ink`.
- Secondary labels: `secondaryInk`.
- Metadata and captions: `tertiaryInk`.
- Primary filled actions: charcoal or system glass prominent, not saturated purple by default.
- Purple appears in icons, toggles, selection states, and small brand surfaces.
- Do not make full screens purple or lavender unless the content is an onboarding hero image.

## Typography

Use Apple’s default SF Pro system typography through the existing `bikeyFont` helper. The app should feel clean and professional rather than playful or overly rounded, with regular and medium weights carrying most of the hierarchy.

Recommended scale:

- Large onboarding title: 30-34 pt, regular or semibold only when needed.
- Screen title: 20-24 pt, regular.
- Card headline: 17-20 pt, regular or medium.
- Body: 14-16 pt, regular.
- Metadata: 11-13 pt, regular.
- Tiny stat labels: avoid below 10 pt unless the value is nonessential.

Rules:

- Prefer `.regular` and `.medium`.
- Use `.bold` sparingly for account names or selected states.
- Do not use negative letter spacing.
- Keep line heights relaxed on onboarding, tighter in controls.
- All text must support Dynamic Type with `@ScaledMetric` or semantic text styles.
- Long Japanese-English examples must have `lineLimit` and `minimumScaleFactor`, or wrap intentionally.

## Shape And Spacing

Use continuous rounded shapes throughout.

```swift
enum BikeyShape {
    static let tiny: CGFloat = 8
    static let small: CGFloat = 12
    static let card: CGFloat = 17
    static let largeCard: CGFloat = 20
    static let hero: CGFloat = 24
    static let sheet: CGFloat = 34
    static let pill: CGFloat = 999
}
```

Spacing:

- Screen horizontal inset: 20-24 pt.
- Section gap: 18-28 pt.
- Card internal padding: 14-20 pt.
- Compact control gap: 8-12 pt.
- Minimum tap target: 44x44 pt.
- Bottom tab height: 64 pt content, with safe-area padding outside it.

Use stable dimensions for controls like tab items, stat pills, icon buttons, toggles, and CTA pills so labels never resize the layout.

## Liquid Glass Rules

Prefer native iOS 26 Liquid Glass APIs.

Implementation rules:

- Use `.glassEffect(...)` for custom glass surfaces on iOS 26+.
- Use `GlassEffectContainer` whenever multiple glass elements are nearby.
- Apply `.glassEffect` after padding, frame, foreground, and appearance modifiers.
- Use `.interactive()` only on tappable elements.
- Use `.buttonStyle(.glass)` for secondary actions.
- Use `.buttonStyle(.glassProminent)` for primary glass actions where the system style fits.
- Provide non-glass fallbacks using white opacity or `.ultraThinMaterial` for earlier iOS versions.
- Do not add shadows to views that already use Liquid Glass.

Recommended helper:

```swift
extension View {
    @ViewBuilder
    func bikeyGlass<S: Shape>(in shape: S, fallback: Color = .white.opacity(0.86)) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: shape)
        } else {
            self.background(fallback, in: shape)
        }
    }

    @ViewBuilder
    func bikeyInteractiveGlass<S: Shape>(in shape: S, fallback: Color = .white.opacity(0.86)) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self.background(fallback, in: shape)
        }
    }
}
```

## Core Components

### Ambient Hero Background

The onboarding and top feature cards should use a soft lavender-gray bitmap background, similar to the Willow screenshots. It should include blur, pale grain, and a darker purple falloff near one edge.

Use this treatment for:

- Onboarding first screen.
- Home feature card.
- Profile membership card.
- Invite/share modal preview area.

Do not use it behind long forms or dense settings.

### Header Row

The home header should match the reference pattern:

- Left: small app icon and app name.
- Center/right: compact stat pill with two metrics.
- Far right: switch-style enable control.

The stat pill and toggle should live in a `GlassEffectContainer`. The row height should be at least 44 pt.

### Bottom Tab Bar

The tab bar should be a floating capsule, centered above the home indicator.

Requirements:

- Four tabs maximum.
- Icon above label.
- Selected state uses purple foreground and filled symbol variant.
- Unselected state uses charcoal/secondary ink.
- The capsule uses Liquid Glass on iOS 26+.
- Legacy fallback uses white opacity and a very soft shadow.
- No colored selection blob unless implemented as a morphing glass indicator.

### Cards

Cards should look like the transcript card in the second screenshot:

- Solid white or 92-96 percent white.
- Corner radius 16-20 pt.
- Soft shadow, low opacity.
- Clear information hierarchy.
- No visible card inside another card.
- Hairline dividers only when separating rows.

### Primary Buttons

Use charcoal or glass prominent capsules.

Style:

- Height: 44-52 pt.
- Full width in sheets and auth screens.
- Compact width only inside feature cards.
- Text: 14-15 pt medium.
- Shape: capsule.

Avoid bright purple filled buttons as the default. Purple can tint glass or indicate selection.

### Icon Buttons

Use circular glass buttons for profile/settings/filter/close actions.

Style:

- Size: 34-44 pt.
- SF Symbol centered.
- Charcoal or secondary ink symbol.
- Use `.interactive()` glass if tappable.
- Close buttons in sheets should sit in the top-right corner.

### Bottom Sheets

Bottom sheets should follow the invite modal screenshot.

Structure:

- Dim the presenting screen with black at 25-35 percent opacity.
- Sheet background: elevated white.
- Top corners: 30-36 pt continuous radius.
- Grab handle: 36x4 pt, light gray, top centered.
- Top-right close glass/circle button when dismissible.
- Content begins 22-28 pt below the top.
- Full-width primary button.
- Secondary button below in a pale capsule.

Use sheets for:

- Invite friends.
- Add dictionary entry.
- Keyboard setup help.
- Sign-out confirmation.
- Upgrade/pro prompts.

## Screen Specs

### Onboarding

The onboarding should be closest to screenshot 1.

Layout:

- Full-screen rounded phone-style ambient background if shown inside screenshots; otherwise full safe-area background.
- Status-safe top spacing.
- Brand mark small above the headline.
- Headline: short, direct, two lines maximum.
- Page dots near the lower third.
- Primary CTA capsule near the bottom.
- Secondary sign-in text below CTA.

Recommended copy:

- Headline: `Stop switching. Start typing.`
- Alternate: `Type Japanese and English naturally.`
- Primary CTA: `Get started`
- Secondary: `Already have an account? Sign in`

Do not add feature lists, tutorial paragraphs, or multiple cards on the first onboarding screen.

#### Onboarding Page Sequence

The onboarding flow has four conceptual pages:

1. **Welcome:** full-screen ambient `gradientwithglobe` background, small Bikey mark, short two-line headline, page dots, a pale glass `Get started` capsule, and inline `Sign in`. This page should be almost identical to the Willow welcome reference, adjusted only for Bikey's sign-up/sign-in paths.
2. **Account:** use the same `gradientwithglobe` background, white header text over the purple upper-left field, white/glass pill fields, and one dark capsule CTA. Sign-up adds username; sign-in uses only email and password.
3. **Enable Keyboard:** keep `gradientwithglobe`, then place the setup instructions in a white elevated card. Ask the user to add Bikey in iOS Settings and show the exact path: `Settings > General > Keyboard > Keyboards > Add New Keyboard > Bikey`.
4. **How It Works:** keep `gradientwithglobe`, then use a compact white visual card explaining detection, suggestions, space confirmation, tapping a candidate, and tapping `Keep` to preserve the original typed text.

The first two pages live in the signed-out flow. Pages three and four are post-auth setup pages and should appear before the user lands on the main app for the first time.

### Home

The home screen should remain compact and utility-focused, close to screenshot 2.

Layout order:

1. Header row with brand, stats, enable toggle.
2. Large feature card with ambient background.
3. Short instructional card or carousel slide.
4. Section title row for recent conversions with filter button.
5. Recent conversion cards.
6. Floating glass tab bar.

The feature card should show the core value through examples, not through a marketing paragraph. Use the Japanese-English mixed input as the visual proof.

### Profile

Profile should blend the repo's current stronger profile work with screenshot 3.

Layout:

1. Top control row with back/settings or notification icons.
2. User identity row with avatar, name, email, plan/word status.
3. Glass or solid promo row: `Get Bikey for Mac or Windows` when relevant.
4. Solid grouped list cards for account/settings.
5. Invite sheet when tapping invite.

The invite sheet should replicate the reference structure:

- Avatar cluster.
- `Invite friends, earn Pro Together`
- Two benefit rows with check icons.
- Primary `Invite friends` button.
- Secondary `Copy invite link` button.

### Dictionary

Dictionary currently should be redesigned, prioritizing the reference style.

Layout:

- Header with title and one circular add button.
- Search field as a soft white rounded pill.
- Empty state as a compact solid card, not a large illustration.
- Entries as white list cards with Japanese/English terms and small metadata.
- Add/edit entry presented as a bottom sheet.

Do not use large dense forms as the first view. Keep dictionary management fast and thumb-friendly.

### Keyboard Settings

The keyboard tab should feel like a settings utility, not a placeholder.

Layout:

- Header title: `Keyboard`
- Status card showing whether Bikey is enabled.
- Setup checklist as solid white rows.
- Composition mode selector as segmented pills.
- Small preview card showing mixed Japanese-English composition.

Use system settings-style grouping with Bikey's softer surfaces.

### Auth Forms

Sign in and sign up should be redesigned around the onboarding visual language.

Layout:

- Ambient background at top or full screen.
- Form in a solid white card or unframed vertical stack.
- Text fields as white rounded pills.
- Primary CTA as charcoal/glass capsule.
- Secondary navigation as inline text.

Keep auth screens sparse. Avoid dense labels, heavy borders, and large explanatory copy.

## Motion

Motion should be subtle and native.

Use:

- Spring response around 0.35-0.45 for tab changes and glass morphs.
- Soft haptic feedback on tab selection and important toggles.
- Matched glass IDs for moving glass indicators.
- Opacity and scale transitions for sheets.

Respect Reduce Motion:

- Disable decorative morphing.
- Keep transitions simple.
- Do not animate large background shifts.

## Accessibility

Every screen must pass:

- Minimum 44x44 pt tap targets.
- Dynamic Type without text clipping.
- VoiceOver labels for icon-only buttons.
- Reduce Transparency with legible fallbacks.
- Increase Contrast in light mode.
- Reduce Motion.

Icon-only buttons must use either `Button("Label", systemImage:)` where visible labels are appropriate, or explicit accessibility labels when visual labels are hidden.

## Implementation Priorities

1. Redesign onboarding/auth first using the screenshot 1 direction.
2. Keep home close to the screenshot 2 structure and refine with actual Liquid Glass.
3. Keep the stronger parts of profile, but add the screenshot 3 bottom-sheet language for invite/share flows.
4. Redesign dictionary and keyboard settings from scratch around this document.
5. Normalize shared colors, typography, metrics, and glass helpers.
6. Snapshot-test home and profile after visual changes, then add snapshots for onboarding and dictionary.

## Design Review Checklist

Before considering a screen done:

- The first viewport looks like a native iPhone app, not a web page.
- The screen has one clear primary action or primary browsing task.
- Glass appears only on controls/chrome.
- Solid content cards are readable without transparency.
- Purple is an accent, not the whole palette.
- Typography is calm, clean, and not over-bold.
- There are no nested cards.
- There are no decorative blobs or generic gradients.
- Text fits at small and large Dynamic Type sizes.
- The screen still works when Liquid Glass falls back on older iOS versions.
