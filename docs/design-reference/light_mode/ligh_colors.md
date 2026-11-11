---
name: Botanical Sanctuary
colors:
  surface: '#fef8f6'
  surface-dim: '#ded9d7'
  surface-bright: '#fef8f6'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f8f2f0'
  surface-container: '#f2edeb'
  surface-container-high: '#ede7e5'
  surface-container-highest: '#e7e1df'
  on-surface: '#1d1b1a'
  on-surface-variant: '#50453b'
  inverse-surface: '#32302f'
  inverse-on-surface: '#f5efed'
  outline: '#82756a'
  outline-variant: '#d4c4b7'
  surface-tint: '#7d562d'
  primary: '#7d562d'
  on-primary: '#ffffff'
  primary-container: '#d4a373'
  on-primary-container: '#5b3912'
  inverse-primary: '#f0bd8b'
  secondary: '#5a6242'
  on-secondary: '#ffffff'
  secondary-container: '#dee7bf'
  on-secondary-container: '#606848'
  tertiary: '#5c6145'
  on-tertiary: '#ffffff'
  tertiary-container: '#abaf8e'
  on-tertiary-container: '#3e4229'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdcbd'
  primary-fixed-dim: '#f0bd8b'
  on-primary-fixed: '#2c1600'
  on-primary-fixed-variant: '#623f18'
  secondary-fixed: '#dee7bf'
  secondary-fixed-dim: '#c2cba4'
  on-secondary-fixed: '#171e06'
  on-secondary-fixed-variant: '#424a2d'
  tertiary-fixed: '#e1e6c2'
  tertiary-fixed-dim: '#c5c9a7'
  on-tertiary-fixed: '#1a1d07'
  on-tertiary-fixed-variant: '#45492f'
  background: '#fef8f6'
  on-background: '#1d1b1a'
  surface-variant: '#e7e1df'
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
    fontWeight: '500'
    lineHeight: 44px
  headline-lg-mobile:
    fontFamily: Newsreader
    fontSize: 26px
    fontWeight: '500'
    lineHeight: 34px
  headline-md:
    fontFamily: Newsreader
    fontSize: 28px
    fontWeight: '500'
    lineHeight: 36px
  headline-sm:
    fontFamily: Newsreader
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 30px
  title-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 26px
  title-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 18px
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1.5rem
  gutter-mobile: 1rem
  margin: 3rem
  margin-mobile: 1.25rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.5rem
---

## Brand & Style

This design system embodies an earthy, organic tactile aesthetic paired with the quiet precision of high-end editorial layouts. Designed for wellness, sustainable commerce, architectural living, and refined botanical lifestyle platforms, the interface evokes grounding warmth, calm focus, and sensory tangibility. 

The aesthetic synthesizes modern minimalism with organic tactile surfaces:
- Generous, airy negative space anchored by warm, luminous ivory and linen backdrops.
- Soft, paper-like tactile containers that evoke heavy artisanal cardstock rather than synthetic glass or plastic.
- Deliberate typographic harmony pairing a literary, humanist serif display face with a clean, structural grotesque for high-density legibility.
- Deep espresso and slate-charcoal text ensuring accessibility and contrast across warm parchment grounds.

## Colors

The palette draws strictly from natural pigments, sun-baked clay, unbleached fibers, and muted botanical leaves. Every tone is balanced to remain soft and non-jarring under daylight while maintaining AA/AAA accessibility standards.

### Functional Roles
- **Primary Accent (`#D4A373`):** Warm caramel terracotta / rich camel amber. Applied to primary call-to-actions, prominent badges, highlighted active indicator states, and key navigational points.
- **Secondary (`#CCD5AE`):** Soft sage olive. Used for supportive decorative accents, secondary action indicators, organic pill tags, and success validation badges.
- **Tertiary (`#E9EDC9`):** Light pale sage linen. Functions as subtle highlight fills, secondary tag backdrops, active toggle tracks, and contextual alert backgrounds.
- **Neutral Foreground (`#2C2A29` / `#1C1917`):** Dark slate espresso. Replaces harsh synthetic blacks for all body copy, headers, and structural lines, providing warm yet rigorous contrast.
- **Surface Canvas (`#FEFAE0`):** Warm cream ivory. The primary window/app background surface, delivering a sunlit, unbleached parchment warmth.
- **Surface Elevated (`#FAEDCD`):** Soft champagne almond bisque. Used for cards, panels, floating sheets, and input fields to construct natural tonal hierarchy without clinical borders.

## Typography

The type system balances literary editorial warmth with contemporary geometric clarity.

- **Headlines (`Newsreader`):** Display sizes rely on Newsreader's organic, bookish serif forms with optical sizing that conveys crafted authority. Used across titles, feature statements, and modal headlines. Italics should be used sparingly for poetic emphasis or editorial subheaders.
- **Body & Labels (`Plus Jakarta Sans`):** Selected for its humanist geometry, slightly rounded terminals, and exceptional open apertures that complement the soft botanical aesthetic while maintaining crisp legibility down to 11px.
- **Tracking:** Headings carry neutral letter spacing (`0em`), while uppercase tags and mini labels carry a gentle expansion (`+0.04em`) to ensure legibility on tinted almond backgrounds.

## Layout & Spacing

The layout is structured around an unhurried, breathable fluid grid system built to feel like an open physical editorial spread.

- **Desktop (>= 1024px):** 12-column layout with generous outer margins of `3rem` (48px) and standard gutters of `1.5rem` (24px). Max container width is constrained to `1280px` to maintain comfortable eye scanning distance.
- **Tablet (768px - 1023px):** 8-column layout with `2rem` margins and `1.25rem` gutters.
- **Mobile (< 768px):** 4-column layout with `1.25rem` outer margins and `1rem` gutters. Stacks components vertically and prioritizes continuous flow.
- **Vertical Rhythm:** Space out semantic content blocks using `space-xl` (40px) to prevent cognitive density and maintain the serene, spa-like experience.

## Elevation & Depth

Visual hierarchy is constructed primarily through **tonal layering** and **warm ambient shadows**, entirely eschewing harsh gray drop shadows or stark black overlays.

- **Tonal Layering:** The foundational layer is Canvas (`#FEFAE0`). Raised surfaces, cards, and modal sheets sit on Almond Bisque (`#FAEDCD`). Micro-surfaces, tags, and internal nested boxes drop into Pale Sage Linen (`#E9EDC9`).
- **Warm Ambient Shadows:** When elevation is required for floating navigation, popovers, or interactive hover states, shadows use warm umber tints instead of neutral charcoal:
  - *Elevation 1 (Cards, Rest):* `0 2px 8px -2px rgba(44, 42, 41, 0.05), 0 1px 3px 0 rgba(212, 163, 115, 0.08)`
  - *Elevation 2 (Hover states, Drawers):* `0 8px 24px -4px rgba(44, 42, 41, 0.08), 0 3px 6px -1px rgba(212, 163, 115, 0.12)`
  - *Elevation 3 (Modals, Overlays):* `0 20px 32px -8px rgba(28, 25, 23, 0.12), 0 8px 16px -2px rgba(212, 163, 115, 0.14)`
- **Hairline Outlines:** When structural separation is necessary, use a subtle 1px border colored with a 15% opacity tint of terracotta or muted sage (`rgba(212, 163, 115, 0.25)` or `rgba(204, 213, 174, 0.35)`).

## Shapes

The shape system adopts a soft, ergonomic curvature (`roundedness: 2`), reflecting natural, river-worn stones and plant geometry:
- Standard interactive elements (buttons, text inputs, chips) feature `0.5rem` (8px) border radius.
- Cards, containers, and group sections adopt `rounded-lg` at `1rem` (16px).
- Modal dialogues, hero cards, and floating bottom sheets use `rounded-xl` at `1.5rem` (24px).
- Status indicators, avatars, and badge counters use full pill curvature (`9999px`).

## Components

### Buttons
- **Primary:** Background `#D4A373`, text `#1C1917` (or stark white depending on contrast validation; deep espresso preferred for botanical warmth), border-radius `0.5rem`. Hover state introduces a smooth scale (`1.01`) and background shifts to a deeper amber terracotta (`#C59262`).
- **Secondary:** Background `#CCD5AE` with dark slate text `#2C2A29`. On hover, lightens toward `#D8E0BC`.
- **Tertiary / Ghost:** Transparent background with subtle border `1px solid rgba(212, 163, 115, 0.4)`, text `#2C2A29`. Hover fills with `#FAEDCD` at 50% opacity.

### Chips & Badges
- Filter pills and tags utilize `#E9EDC9` backgrounds with `#2C2A29` text.
- Active or selected states switch to `#D4A373` with `#FEFAE0` text.
- Padding is compact: `space-xs` (4px) vertical by `space-sm` (8px) horizontal, with rounded pill shapes.

### Input Fields
- Built on `#FAEDCD` backgrounds with a faint border `1px solid rgba(44, 42, 41, 0.12)`.
- Active focus state shifts the border to `#D4A373` with an ambient glow of `0 0 0 3px rgba(212, 163, 115, 0.25)`.
- Placeholder text uses muted espresso at 45% opacity.

### Cards
- Surface base is `#FAEDCD` rested over `#FEFAE0`.
- Padding uses `space-lg` (24px) for desktop and `space-md` (16px) for mobile.
- Cards rely on Elevation 1 ambient shadows with no hard borders, creating a soft, tactile presence like heavy unbleached cotton stationery.

### Checkboxes & Radios
- Unchecked: `#FAEDCD` interior with a 1.5px border of `rgba(44, 42, 41, 0.25)`.
- Checked: Filled with `#D4A373`, showing a clean ivory `#FEFAE0` checkmark or center pip.
- Transition is smooth (150ms ease-out) to enhance physical responsiveness.

### Contextual Banners & Accordions
- Expandable accordions feature hairline dividers in `#E9EDC9` and toggle icons that rotate softly.
- Information banners use a calm wash of `#E9EDC9` with dark espresso copy and subtle `#CCD5AE` iconography.