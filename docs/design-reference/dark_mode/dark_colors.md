---
name: Botanical Nocturne
colors:
  surface: '#101412'
  surface-dim: '#101412'
  surface-bright: '#363a38'
  surface-container-lowest: '#0b0f0d'
  surface-container-low: '#181c1a'
  surface-container: '#1c201e'
  surface-container-high: '#272b29'
  surface-container-highest: '#323633'
  on-surface: '#e0e3e0'
  on-surface-variant: '#d5c3b4'
  inverse-surface: '#e0e3e0'
  inverse-on-surface: '#2d312f'
  outline: '#9e8e80'
  outline-variant: '#514539'
  surface-tint: '#faba75'
  primary: '#fcbc76'
  on-primary: '#482900'
  primary-container: '#dda15e'
  on-primary-container: '#5f3800'
  inverse-primary: '#835418'
  secondary: '#becca3'
  on-secondary: '#293417'
  secondary-container: '#414d2e'
  on-secondary-container: '#b0be96'
  tertiary: '#a7d4a3'
  on-tertiary: '#113816'
  tertiary-container: '#8cb889'
  on-tertiary-container: '#224925'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdcbb'
  primary-fixed-dim: '#faba75'
  on-primary-fixed: '#2b1700'
  on-primary-fixed-variant: '#673d00'
  secondary-fixed: '#dae8be'
  secondary-fixed-dim: '#becca3'
  on-secondary-fixed: '#141f05'
  on-secondary-fixed-variant: '#3f4b2c'
  tertiary-fixed: '#c1eebc'
  tertiary-fixed-dim: '#a5d2a2'
  on-tertiary-fixed: '#002106'
  on-tertiary-fixed-variant: '#284f2a'
  background: '#101412'
  on-background: '#e0e3e0'
  surface-variant: '#323633'
typography:
  headline-xl:
    fontFamily: Newsreader
    fontSize: 48px
    fontWeight: '400'
    lineHeight: 56px
  headline-xl-mobile:
    fontFamily: Newsreader
    fontSize: 32px
    fontWeight: '400'
    lineHeight: 40px
  headline-lg:
    fontFamily: Newsreader
    fontSize: 36px
    fontWeight: '400'
    lineHeight: 44px
  headline-lg-mobile:
    fontFamily: Newsreader
    fontSize: 26px
    fontWeight: '400'
    lineHeight: 34px
  headline-md:
    fontFamily: Newsreader
    fontSize: 28px
    fontWeight: '500'
    lineHeight: 36px
  headline-sm:
    fontFamily: Newsreader
    fontSize: 22px
    fontWeight: '500'
    lineHeight: 28px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 22px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-desktop: 1.5rem
  margin: 1rem
  margin-tablet: 2rem
  margin-desktop: 3rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.5rem
---

## Brand & Style
The design system manifests an intimate, editorial night-sanctuary tailored for deep focus and mindful notification orchestration. It shifts the organic warmth of sunlit terracotta and sage into a cinematic, low-light environment characterized by obsidian slates, warm earthen shadows, and glowing clay embers. 

Rooted in a synthesis of **Organic Minimalism** and **Editorial Warmth**, the visual language prioritizes atmospheric tranquility without sacrificing utility. Interfaces evoke the sensation of an architecturally illuminated nocturnal conservatory: deep botanical dark surfaces, tactile earthen accents, fine hairline contours, and high-legibility literary typography. The experience is designed to reduce neurological friction, transform chaotic inbound alerts into curated rituals, and cultivate an aura of prestige, quiet luxury, and centered productivity.

## Colors
The palette translates organic botanical life into deep-slate chromatic tiers, avoiding pure neutral blacks in favor of verdant-tinted obsidians.

- **Background Canvas & Base Tiers:**
  - `canvas-default`: `#0F1312` (deep obsidian slate root)
  - `surface-base`: `#141816` (recessed screen canvas)
  - `surface-raised`: `#1C221F` (standard component surface)
  - `surface-container`: `#1E2622` (interactive/grouped cards)
  - `surface-container-high`: `#26302B` (elevated sheets, floating panels, hovered cards)

- **Brand Accents & Highlights:**
  - `primary` (`#DDA15E`): Warm luminous terracotta for high-emphasis primary actions, key active indicators, and focus states.
  - `primary-hover`: `#E8A87C` (softened terracotta ember for hover and tap transitions).
  - `secondary` (`#A3B18A`): Soft sage leaf for informational badges, active tags, and progressive indicators.
  - `tertiary` (`#588157`): Deep forest sage for toggles, success feedback, and organic visual grounding.

- **Borders & Dividers:**
  - `border-subtle`: `#2C3831` (structural hairlines, table borders, card edges)
  - `border-strong`: `#38463D` (interactive borders, active input boundaries)

- **Typography & Glyphs:**
  - `text-primary`: `#F3F4F1` (crisp, high-contrast alabaster cream)
  - `text-secondary`: `#E2E4DE` (softened muted stone for body hierarchy)
  - `text-tertiary`: `#8A948D` (subtle captions, timestamps, placeholder metadata)

## Typography
Typographic rhythm sets an intellectual, editorial pace through the contrast between **Newsreader** (expressive, organic, serif) and **Plus Jakarta Sans** (clean, humanist, geometry).

- **Headlines (Newsreader):** Used for view titles, section headers, milestone modal titles, and empty-state messaging. Rendered in regular or medium weights to preserve delicate optical strokes. Italic variations are reserved strictly for ambient status phrases and curated workflow headers.
- **Body & Labels (Plus Jakarta Sans):** Carries all transactional UI, notification content, metadata, button text, and system controls. Ensures instant scanability across dense alert lists and high-frequency communication flows.

## Layout & Spacing
The layout employs an 8pt architectural rhythm to structure content density without visual exhaustion.

- **Responsive Grid Model:**
  - **Mobile (<768px):** 4-column fluid layout with `1rem` (16px) margins and gutters. Single-column stacked notification feeds with compact spacing.
  - **Tablet (768px–1024px):** 8-column layout with `2rem` (32px) margins and `1rem` (16px) gutters. Splits navigation and detail views into structured master-detail panels.
  - **Desktop (>1024px):** 12-column layout capped at a maximum width of `1280px`, with `3rem` (48px) margins and `1.5rem` (24px) gutters. Multi-column dashboard surfaces orchestrate real-time notification triage and contextual filters.

- **Internal Component Spacing:**
  - Padding for interactive elements adheres strictly to `space-sm` (8px) vertically and `space-md` (16px) horizontally.
  - Stacked list items use `space-sm` gaps to maintain grouping cohesiveness.

## Elevation & Depth
In this botanical dark mode, elevation relies primarily on tonal luminosity stepping and tinted amber-slate ambient occlusion rather than standard harsh drop shadows.

- **Tonal Stepping:** Surfaces ascend closer to the user by shifting from deep canvas (`#0F1312`) to surface containers (`#1E2622` and `#26302B`).
- **Hairline Boundaries:** Every elevated card, sheet, and popover incorporates a `1px` crisp border using `#2C3831` (or `#38463D` when focused) to delineate planes without visual bulk.
- **Ambient Glow & Shadows:**
  - **Low Elevation (Cards, Panels):** `0px 2px 8px rgba(5, 8, 7, 0.45), 0px 1px 2px rgba(0, 0, 0, 0.35)`.
  - **High Elevation (Dropdowns, Sheets, Dialogs):** `0px 12px 32px rgba(5, 8, 7, 0.65), 0px 2px 6px rgba(0, 0, 0, 0.45)`.
  - **Luminous Accent (Primary CTA, Activated Toggles):** A warm, diffused amber aura `0px 0px 16px rgba(221, 161, 94, 0.18)` applied to terracotta elements to evoke an organic inner light.

## Shapes
The shape philosophy conforms directly to `ROUND_EIGHT` (`0.5rem` / `8px` baseline curvature), ensuring strict continuity with the tactile Dark Mode application icon.

- **Base Radius (`0.5rem` / 8px):** Applied to standard action buttons, input fields, filter tags, list items, checkboxes, and badge containers.
- **Large Radius (`1rem` / 16px):** Applied to composite notification cards, settings modules, and dashboard analytics panels.
- **Extra Large Radius (`1.5rem` / 24px):** Dedicated to floating bottom sheets, standalone modals, and primary application shells.
- **Pill Radius (`9999px`):** Used exclusively for high-status live alert counters, active channel tags, and switch thumbs.

## Components

- **Buttons:**
  - *Primary:* Terracotta background (`#DDA15E`), deep slate text (`#0F1312`), font-weight 600, `8px` border-radius. Subtle terracotta aura hover (`#E8A87C`).
  - *Secondary:* Dark slate surface (`#1E2622`), hairline border (`#2C3831`), off-white text (`#F3F4F1`). On hover, transitions surface to `#26302B` and border to `#38463D`.
  - *Ghost / Tertiary:* Transparent background, sage text (`#A3B18A`), active state tinted with `rgba(163, 177, 138, 0.08)`.

- **Cards & Notification Items:**
  - Rendered with `#1E2622` background, `1px` border in `#2C3831`, and `16px` outer border-radius (`rounded-lg`).
  - Unread notifications feature a subtle vertical terracotta indicator on the left inset edge (`3px` width, `#DDA15E`) and a subdued background illumination.

- **Chips & Badges:**
  - Categorical filter chips utilize `#141816` background with `#2C3831` borders.
  - Active category chips use soft sage overlay (`rgba(163, 177, 138, 0.12)`) with `#A3B18A` text and `#588157` active borders.
  - Notification counter badges feature a pill radius with `#588157` surface and crisp `#F3F4F1` typography.

- **Inputs & Search Bars:**
  - Recessed field in `#141816`, bordered by `#2C3831` with `8px` corner radius.
  - Caret and active focus ring shift smoothly to terracotta `#DDA15E` with `0 0 0 1px #DDA15E`. Placeholder text sits at `#8A948D`.

- **Toggles & Form Controls:**
  - Checkboxes use `8px` rounded squares with `#2C3831` borders; checked state fills with `#588157` and displays an off-white `#F3F4F1` checkmark.
  - Switch tracks feature `#141816` in the off state and `#588157` when active; switch thumbs glow in warm alabaster `#F3F4F1`.

- **Notification Feed Channel Rail:**
  - Left-hand contextual rail organizing channels (VIP, System, Batched) with custom iconography framed in `8px` soft rounded tiles with subtle `#2C3831` separators.