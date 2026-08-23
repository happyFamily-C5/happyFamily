# happyFamily — App Icon Generation Prompt

**App concept:** happyFamily is an app for **depositing textile waste (~limbah tekstil) at designated drop points (~drop point)** for collection. The icon should read as *sustainability / textile recycling / circular economy* — friendly and accessible.

## Recommended direction
A friendly soft 3D mascot/emblem that says "recycle your clothes here": a round t-shirt / fabric-form character with simple dot eyes, gently holding or resting on a recycling loop, OR a bold glossy t-shirt symbol wrapped in a circular recycling arrow. One strong, instantly readable silhouette — not a stuffed scene.

## Prompt to run
Generate with **Gemini 3 Pro Image (Nano Banana)** or any modern image model at **1024×1024 PNG**, then run `./scripts/prepare_app_icons.sh <file>`.

```
Create a 1024x1024 square app icon — premium, vibrant and dimensional, in the style of top App Store featured apps.

Subject: a single soft glossy 3D friendly t-shirt / folded-fabric mascot character for a textile-recycling app. The fabric form is rounded and cute with simple dot eyes, and it is gently hugged by (or sits inside) a smooth glossy recycling loop arrow. Instantly readable at small sizes. No human faces, no text.

The look: one dimensional hero rendered in soft glossy 3D — smooth color gradients, soft studio lighting, gentle rim light, a subtle soft glow, rounded volumes and real depth — centered on a FULL-BLEED vivid branded background that reaches all four edges. Saturated, high-contrast, polished, delightful. Like a soft glossy jelly/clay form with tasteful highlights.

Background: fill the ENTIRE square edge-to-edge with a vibrant green gradient (fresh, eco) — e.g. leaf-green to deep emerald. Never plain white, never empty. The background is part of the icon.

Subject treatment: dimensional and glossy — soft rounded 3D forms, smooth gradients, gentle white highlights and rim light, a subtle inner glow, clear depth and volume. The fabric/t-shirt form is soft cream-white and sky-blue, and the recycling loop is a bright fresh green with a subtle white sheen.

Color palette: vivid leaf-green-to-emerald gradient background; glossy cream-white and sky-blue fabric mascot form; bright fresh-green glossy recycling loop accent.

Composition: the hero centered, filling ~60-80% of the canvas with comfortable breathing room; the brand background fills the rest to the edges. One focal point, no clutter.

Do NOT: flat monochrome pictogram, black-on-white or white-on-white glyph, single-color line/silhouette icon, plain SVG/vector symbol, sticker or clip-art; plain white or empty background; a smaller rounded card/icon floating inside the canvas (no icon-in-icon, no outer margins); baked rounded corners (keep a full square with sharp 90-degree corners — iOS applies its own mask); any text, letters, numbers, monograms or watermark; realistic human faces; real or trademarked logos; mirror chrome, garish neon, or lens flares.

Technical: square 1:1; background bleeds to all four edges with sharp corners; keep critical details within the central ~70% so a rounded mask never clips them; punchy and readable at 60px.
```

## After generation
```bash
./scripts/prepare_app_icons.sh /path/to/generated-icon.png
```
This installs the processed 1024×1024, alpha-free icon into both:
- `Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (main app)
- `HappyFamilyAppClips/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (App Clip)

> Note: a new icon requires a native rebuild to appear — it will not show on hot reload.