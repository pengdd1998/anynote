---
name: AnyNote
description: "Warm paper, six pastel sticky notes and handwriting, with one soft purple accent and paper-like motion."
colors:
  # Values are the Dart literals declared in frontend/lib/core/theme (8-digit hex where the token carries alpha).
  # Trailing comment on each line: "# role · descriptive name".
  # ---- Primary: the one control accent
  primary: "#8B7CE8" # primary · Soft Periwinkle Purple
  primary-dark: "#7466D6" # primary · Deep Pressed Purple
  secondary: "#B7ADF5" # primary · Light Periwinkle
  on-primary: "#FFFFFF" # neutral · On-Primary White
  primary-soft: "#EFECFE" # primary · Lavender Tint
  primary-soft-border: "#DCD5FA" # primary · Lavender Tint Border
  primary-text: "#6C5BC4" # primary · Deep Accent Purple
  primary-container-dark: "#463D6B" # primary · Dark Lavender Container
  hc-primary: "#4F3DB8" # primary · High-Contrast Deep Violet
  hc-dark-primary: "#C9C0FF" # primary · High-Contrast Pale Periwinkle
  # ---- Secondary: sticky-note paper, then each sheet's dark wash (calculated from PaperTokens.toneFor, not a code literal)
  paper-yellow: "#FBE48E" # secondary · Morning-Thoughts Yellow
  paper-white: "#F9F4EA" # secondary · Plain Paper
  paper-pink: "#FDD0CB" # secondary · Salmon Pink
  paper-lavender: "#E4D3F6" # secondary · Lavender Note
  paper-cream: "#FCF7EA" # secondary · Tiny-Ideas Cream
  paper-green: "#E2EFD0" # secondary · Plant-Care Mint
  paper-yellow-dark: "#504E49" # secondary · Dark Wash of Morning-Thoughts Yellow (derived)
  paper-white-dark: "#50525E" # secondary · Dark Wash of Plain Paper (derived)
  paper-pink-dark: "#514A57" # secondary · Dark Wash of Salmon Pink (derived)
  paper-lavender-dark: "#4B4A61" # secondary · Dark Wash of Lavender Note (derived)
  paper-cream-dark: "#50525E" # secondary · Dark Wash of Tiny-Ideas Cream (derived)
  paper-green-dark: "#4B5158" # secondary · Dark Wash of Plant-Care Mint (derived)
  light-desk-bg: "#F2EFE9" # secondary · The Desk
  # ---- Tertiary: status colours and the empty-state badge
  error: "#EF4444" # tertiary · Error Red
  success: "#10B981" # tertiary · Success Green
  warning: "#F59E0B" # tertiary · Warning Amber
  accent-lavender-bg: "#F3F0FF" # tertiary · Lavender Badge Tint
  accent-lavender-text: "#7C6AC4" # tertiary · Lavender Badge Ink
  # ---- Neutral: light theme
  light-surface: "#FAF8F5" # neutral · Warm Cream
  light-card-bg: "#FFFDF9" # neutral · Warm Card White
  light-input-fill: "#F5F2EE" # neutral · Warm Input Fill
  light-border: "#E8E4DF" # neutral · Warm Border
  light-divider: "#EBE8E3" # neutral · Warm Divider
  light-disabled: "#D5D0C8" # neutral · Warm Disabled Grey
  light-text-primary: "#0F172A" # neutral · Slate Ink
  light-text-secondary: "#5C534A" # neutral · Warm Brown-Grey Ink
  light-text-tertiary: "#9C8F83" # neutral · Warm Muted Ink
  slate-100: "#F1F5F9" # neutral · Cool Chip Grey
  # ---- Neutral: dark theme
  dark-surface: "#1A1E2E" # neutral · Deep Navy
  dark-card-bg: "#1E2235" # neutral · Navy Card
  dark-input-fill: "#252A3E" # neutral · Navy Input Fill
  dark-border: "#353B52" # neutral · Navy Border
  dark-divider: "#2D3348" # neutral · Navy Divider
  dark-disabled: "#4B5268" # neutral · Navy Disabled
  dark-text-primary: "#F4F2FF" # neutral · Pale Lavender White
  dark-text-secondary: "#C4C0E0" # neutral · Muted Lavender Grey
  dark-text-tertiary: "#9E9AB8" # neutral · Dim Lavender Grey
  # ---- Neutral: shadow inks
  paper-shadow: "#78644226" # neutral · Warm Paper Shadow (alpha 0x26)
  paper-shadow-near: "#7864421F" # neutral · Warm Paper Contact Shadow (alpha 0x1F)
  shadow-dark: "#00000020" # neutral · Dark-Theme Shadow Black (alpha 0x20)
typography:
  # Sizes and tracking are Flutter logical pixels. Line-height values are the Dart `height` multipliers.
  # UI family: Inter (SF Pro Display on iOS). Handwriting: Caveat, with Ma Shan Zheng registered under the same family for Chinese.
  display:
    fontFamily: "Inter"
    fontSize: "36px"
    fontWeight: 800
    lineHeight: 1.21
    letterSpacing: "-0.8px"
  display-warm:
    fontFamily: "Inter"
    fontSize: "40px"
    fontWeight: 800
    lineHeight: 1.15
    letterSpacing: "-1px"
  headline:
    fontFamily: "Inter"
    fontSize: "22px"
    fontWeight: 700
    lineHeight: 1.27
    letterSpacing: "-0.3px"
  title:
    fontFamily: "Inter"
    fontSize: "17px"
    fontWeight: 600
    lineHeight: 1.29
    letterSpacing: "-0.2px"
  body:
    fontFamily: "Inter"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.47
    letterSpacing: "-0.1px"
  caption:
    fontFamily: "Inter"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.38
  link:
    fontFamily: "Inter"
    fontSize: "15px"
    fontWeight: 500
    lineHeight: 1.47
    letterSpacing: "-0.1px"
  mono:
    fontFamily: "RobotoMono"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: "0px"
  handwriting-display:
    fontFamily: "Caveat, MaShanZheng"
    fontSize: "40px"
    fontWeight: 500
    lineHeight: 1.1
    letterSpacing: "0px"
  handwriting-title:
    fontFamily: "Caveat, MaShanZheng"
    fontSize: "28px"
    fontWeight: 500
    lineHeight: 1.15
  handwriting-body:
    fontFamily: "Caveat, MaShanZheng"
    fontSize: "22px"
    fontWeight: 500
    lineHeight: 1.2
  handwriting-caption:
    fontFamily: "Caveat, MaShanZheng"
    fontSize: "17px"
    fontWeight: 500
    lineHeight: 1.2
  handwriting-note-body:
    fontFamily: "Caveat, MaShanZheng"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.45
rounded:
  xxs: "8px"
  xs: "12px"
  sm: "16px"
  md: "20px"
  lg: "24px"
  xl: "28px"
  pill: "9999px"
spacing:
  s2: "2px"
  s4: "4px"
  s8: "8px"
  s12: "12px"
  s16: "16px"
  s20: "20px"
  s24: "24px"
  s32: "32px"
  s40: "40px"
  s48: "48px"
  screen-padding: "16px"
  section-gap: "24px"
  item-gap: "8px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.sm}"
    padding: "14px 24px"
  button-primary-disabled:
    backgroundColor: "{colors.light-disabled}"
    textColor: "{colors.light-text-tertiary}"
    rounded: "{rounded.sm}"
    padding: "14px 24px"
  button-primary-dark:
    backgroundColor: "{colors.secondary}"
    textColor: "{colors.dark-surface}"
    rounded: "{rounded.sm}"
    padding: "14px 24px"
  button-tonal:
    rounded: "{rounded.sm}"
  button-outlined:
    textColor: "{colors.primary}"
    rounded: "{rounded.xs}"
    padding: "14px 24px"
  button-text:
    textColor: "{colors.primary}"
    rounded: "{rounded.xs}"
    padding: "10px 16px"
  input:
    backgroundColor: "{colors.light-input-fill}"
    rounded: "{rounded.sm}"
    padding: "14px 16px"
  input-dark:
    backgroundColor: "{colors.dark-input-fill}"
    rounded: "{rounded.sm}"
    padding: "14px 16px"
  chip:
    backgroundColor: "{colors.slate-100}"
    textColor: "{colors.light-text-primary}"
    rounded: "{rounded.pill}"
    padding: "6px 16px"
  chip-selected:
    backgroundColor: "{colors.primary-soft}"
    textColor: "{colors.primary-text}"
    rounded: "{rounded.pill}"
    padding: "6px 16px"
  chip-dark:
    backgroundColor: "{colors.dark-input-fill}"
    textColor: "{colors.dark-text-primary}"
    rounded: "{rounded.xs}"
    padding: "4px 12px"
  chip-selected-dark:
    backgroundColor: "{colors.primary-container-dark}"
    textColor: "{colors.primary-soft-border}"
    rounded: "{rounded.xs}"
    padding: "4px 12px"
  nav-bar:
    backgroundColor: "{colors.light-card-bg}"
    height: "56px"
  nav-bar-dark:
    backgroundColor: "{colors.dark-card-bg}"
    height: "64px"
  card:
    backgroundColor: "{colors.light-card-bg}"
    rounded: "{rounded.md}"
  settings-group:
    backgroundColor: "{colors.light-card-bg}"
    rounded: "{rounded.md}"
    padding: "4px 0px"
  settings-row:
    typography: "{typography.body}"
    padding: "12px"
  settings-icon-circle:
    size: "32px"
  sticky-note:
    backgroundColor: "{colors.paper-yellow}"
    rounded: "{rounded.xs}"
    padding: "14px 14px 12px 14px"
    typography: "{typography.handwriting-body}"
  sticky-note-dark:
    backgroundColor: "{colors.paper-yellow-dark}"
    rounded: "{rounded.xs}"
    padding: "14px 14px 12px 14px"
    typography: "{typography.handwriting-body}"
  note-card-list:
    backgroundColor: "{colors.light-card-bg}"
    rounded: "{rounded.md}"
    padding: "14px 16px"
    typography: "{typography.handwriting-body}"
  empty-state-icon:
    backgroundColor: "{colors.accent-lavender-bg}"
    size: "72px"
    rounded: "{rounded.md}"
  dialog:
    backgroundColor: "{colors.light-card-bg}"
    rounded: "{rounded.lg}"
  bottom-sheet:
    backgroundColor: "{colors.light-card-bg}"
    rounded: "{rounded.xl}"
  snackbar:
    backgroundColor: "{colors.dark-card-bg}"
    textColor: "{colors.dark-text-primary}"
    rounded: "{rounded.xs}"
---

# Design System: AnyNote

## Overview

**Creative North Star: "The Paper Desk"**

AnyNote's screens are a warm paper desk. A note is not a row in a database: it is a sheet of pastel sticky-note paper, slightly tilted, resting on the desk under a soft warm shadow, with its title and timestamp in handwriting. Around the notes the interface keeps quiet — cream surfaces, warm near-black ink, generous rounded corners, and one soft purple accent that belongs to controls and state. Paper and handwriting are the product's voice; the direction confirmed on 2026-11-24 has the system layer speak the same language, and the owner chose to amplify that personality (视觉方向「放大个性」) rather than restrain it.

The app is phone-first and comfortable rather than dense. Material 3 governs structure, navigation and interaction, spacing sits on a 4 px grid, and corners are large (the radius scale runs 8–28, plus a pill). There are two full themes. Light is the desk itself, with the six paper tones at full strength. Dark is a deep navy where the same six tones survive only as faint washes and the accent lightens to periwinkle so it still reads. Two high-contrast themes (black on white, and the reverse) exist as a separate choice. Motion behaves like paper (动效「更有表现力」): a note lands and settles, a page is lifted onto the desk to open it, a press gives slightly. Four durations, two curves and two springs cover all of it, and "减少动画" calms every bit of it.

The North Star name and the descriptive colour names in this document were derived by the documenter from the direction the owner confirmed on 2026-11-24 and from the code's own token names. The owner has not reviewed them; they are waiting for that review.

**Key Characteristics:**
- Warm paper surfaces with one soft purple accent, used for controls and state.
- Six pastel sticky-note tones, cycled by list position and tilted like hand-placed paper.
- Handwriting for a note's own words; Inter for everything the interface says.
- One icon family — Phosphor line (`Regular`), drawn through `AppIcons`.
- Paper-like motion from four durations, two curves and two springs; "减少动画" calms all of it.

## Colors

Warm paper neutrals, one periwinkle-purple accent for controls, and six pastel sticky-note tones that belong to notes.

### Primary

- **Soft Periwinkle Purple** (#8B7CE8): the only control accent. Filled buttons and the FAB, the focused input border, selected tab and navigation item, the switch thumb, progress indicators, the tinted circle behind a settings icon, and the pin on a note card. It is also the seed the rest of the `ColorScheme` is derived from.
- **Deep Pressed Purple** (#7466D6): the deeper purple the code marks as "pressed"; it is pinned as the light theme's `secondary` role. Despite the slug it is not the dark theme's primary.
- **Light Periwinkle** (#B7ADF5): the dark theme's `primary`. Filled buttons and accents on navy carry Deep Navy ink on it.
- **On-Primary White** (#FFFFFF): the label on a filled button in the light theme.
- **Lavender Tint** (#EFECFE): the light theme's `primaryContainer`. Selected chip background, navigation-bar indicator, and the tone a sticky note takes while selected.
- **Lavender Tint Border** (#DCD5FA): declared as the soft border of the lavender tints; the same value is what the dark theme pins as `onPrimaryContainer`, the label colour on a selected chip.
- **Deep Accent Purple** (#6C5BC4): the light theme's `onPrimaryContainer` — the label on a selected chip — and the declared colour for link text and body accents.
- **Dark Lavender Container** (#463D6B): the dark theme's `primaryContainer` (selected chip, navigation indicator in dark).
- **High-Contrast Deep Violet** (#4F3DB8) and **High-Contrast Pale Periwinkle** (#C9C0FF): the accent of the high-contrast light and dark themes. These two theme choices are the only place the `Bold` icon cut is used.

### Secondary

The second colour family is the paper the notes are written on.

- **Morning-Thoughts Yellow** (#FBE48E), **Plain Paper** (#F9F4EA), **Salmon Pink** (#FDD0CB), **Lavender Note** (#E4D3F6), **Tiny-Ideas Cream** (#FCF7EA), **Plant-Care Mint** (#E2EFD0): the sticky-note sheets, in cycle order. How they are assigned is in Components → Sticky-Note Card.
- **The dark washes** — Dark Wash of Morning-Thoughts Yellow (#504E49), Plain Paper (#50525E), Salmon Pink (#514A57), Lavender Note (#4B4A61), Tiny-Ideas Cream (#50525E), Plant-Care Mint (#4B5158): each is its sheet's tone laid at alpha 58 over Navy Card (#1E2235), which is what `PaperTokens.toneFor` computes at runtime. These six values were calculated by the documenter from that formula (to within one step per channel); they are not literals in the code. In the wash, Plain Paper and Tiny-Ideas Cream come out the same, and all six sit within a few steps of one another — in dark mode the sheets are told apart mostly by tilt, not colour.
- **The Desk** (#F2EFE9): the page background behind sticky notes in light mode, one step deeper than the app surface so the sheets stand out. In dark mode the desk is the normal surface.

### Tertiary

- **Error Red** (#EF4444): the sync-conflict badge; the declared error colour.
- **Success Green** (#10B981) and **Warning Amber** (#F59E0B): the synced and pending states of the sync badge.
- **Lavender Badge Tint** (#F3F0FF) with **Lavender Badge Ink** (#7C6AC4): the 72 px icon badge of an empty state.

### Neutral

Neutrals are warm-tinted in light mode and navy-lavender in dark, with one cool exception noted below.

- **Warm Cream** (#FAF8F5): page and app-bar background in light.
- **Warm Card White** (#FFFDF9): cards, bottom navigation, dialogs, bottom sheets, popup menus in light.
- **Warm Input Fill** (#F5F2EE): filled text inputs in light.
- **Warm Border** (#E8E4DF): input borders, the 1 px border of a settings group and of a list-layout note card.
- **Warm Divider** (#EBE8E3): dividers.
- **Warm Disabled Grey** (#D5D0C8): disabled filled button, disabled switch thumb.
- **Slate Ink** (#0F172A): primary text; also the title ink on a sticky note.
- **Warm Brown-Grey Ink** (#5C534A): secondary text, default icon colour, the preview text on a note.
- **Warm Muted Ink** (#9C8F83): tertiary text, input hints, timestamps.
- **Cool Chip Grey** (#F1F5F9): the light-theme chip background. It is the one cool neutral in a warm set (declared as `slate100`).
- **Deep Navy** (#1A1E2E): page and app-bar background in dark.
- **Navy Card** (#1E2235), **Navy Input Fill** (#252A3E), **Navy Border** (#353B52), **Navy Divider** (#2D3348), **Navy Disabled** (#4B5268): the dark counterparts of card, input fill, border, divider and disabled.
- **Pale Lavender White** (#F4F2FF), **Muted Lavender Grey** (#C4C0E0), **Dim Lavender Grey** (#9E9AB8): the three dark text tiers.
- **Warm Paper Shadow** (#78644226) and **Warm Paper Contact Shadow** (#7864421F): the two layers under a sticky note in light mode.
- **Dark-Theme Shadow Black** (#00000020): every shadow in the dark theme.

The two shadow inks for the light theme's general shadows are deliberately not in this list: their alpha is 0, so they are not colours anything shows. They are recorded in Elevation & Depth.

**Declared but not seen used.** `AppColors` also declares an older six-colour `note*` pastel set with matching border colours, a slate and an indigo ramp, warm accent fills for lavender, yellow, mint, peach and coral (plus backgrounds and inks for all but lavender), per-theme semantic tints, `primaryDisabled` and `info`. None of them is used by the theme or by the component files read for this document, so they are left out of the frontmatter. Two sticky-note palettes therefore coexist in the code; only the `paper*` set is wired in, through `PaperTokens`.

**Contrast: the goal, and the drift.** The goal is WCAG AA (4.5:1) for body and secondary text in both themes (PRODUCT.md). The pairs below fall short in the shipped build. They are drift, not the standard, and none of them is repaired here:

- **Warm Muted Ink on Warm Cream**, the tertiary tier, is about 2.97:1 (3.10:1 on Warm Card White). The comments in `app_colors.dart` and `app_theme.dart` say every tier meets AA; by this measure the tertiary tier does not.
- **White on Soft Periwinkle Purple**, the label on a light-theme filled button, is about 3.42:1. In dark, Deep Navy on Light Periwinkle is 8.12:1 and passes.
- **Soft Periwinkle Purple as text on Warm Cream** is about 3.22:1. This is the label colour of text and outlined buttons, section headers and selected tabs. The palette already holds a purple that passes for text — Deep Accent Purple is 5.04:1 — but those controls do not use it.
- **The timestamp ink on a sticky note** (Warm Muted Ink on the paper tones) is about 2.24–2.94:1 depending on the sheet — lowest on Lavender Note and Salmon Pink, highest on Tiny-Ideas Cream. The title ink (12.7:1 and up) and the preview ink (5.4:1 and up) pass on every sheet.

On the two dark surfaces — Deep Navy and Navy Card — all three dark text tiers pass (5.8:1 and higher). On the dark washes that notes sit in they do not: there the timestamp tier is about 2.87:1 and the preview tier about 4.4:1.

### Named Rules

**The Accent Is for Controls Rule.** Purple marks controls and state — buttons, focus, selection, the pin. The six paper tones mark notes. A sticky note takes the accent only for state: its pin and its selection tint.

**The Six Sheets Rule.** A sticky note's colour is one of the six paper tones, picked by its position in the list. A note's own colour setting only chooses among those six; any other colour becomes a faint 40-alpha wash.

## Typography

**Display Font:** Inter (SF Pro Display on iOS)
**Body Font:** Inter (SF Pro Display on iOS)
**Handwriting Font:** Caveat (with Ma Shan Zheng for Chinese)
**Mono Font:** RobotoMono

**Character:** Two voices. Inter is a plain, slightly tight-tracked sans that keeps the interface quiet. Caveat is the loose handwritten hand that makes a note look written rather than entered, and it is set larger than its UI neighbours (a note title is 22 px handwritten beside 17 px UI titles).

### Hierarchy

- **Display** (800, 36px / 1.21, −0.8px tracking): `display`, mapped to Material `displayMedium`. Its warm variant `display-warm` (800, 40px / 1.15, −1px) is `displayLarge` and is the declared hero style for brand moments — login, onboarding, empty states.
- **Headline** (700, 22px / 1.27, −0.3px): `headline`, mapped to `headlineMedium`; the Material mapping also derives 26px and 18px steps.
- **Title** (600, 17px / 1.29, −0.2px): `title`, mapped to `titleLarge`; used for empty-state titles. The Material mapping derives 15px / 500 and 13px / 500 steps from it.
- **Body** (400, 15px / 1.47, −0.1px): `body`, mapped to `bodyLarge`; settings-row titles and input text. `bodyMedium` is the same at 14px.
- **Caption** (400, 13px / 1.38): `caption`, mapped to `bodySmall` and `labelMedium`; subtitles, hints and metadata. `labelLarge` is the same at 14px / 500.
- **Link** (500, 15px / 1.47, −0.1px, underlined): `link`; the accent colour is applied where it is used.
- **Mono** (400, 13px / 1.5): RobotoMono, for inline code.
- **Handwriting** — `handwriting-display` (500, 40px / 1.1), `handwriting-title` (500, 28px / 1.15), `handwriting-body` (500, 22px / 1.2), `handwriting-caption` (500, 17px / 1.2), `handwriting-note-body` (400, 15px / 1.45).

Control text is set inline in the theme, not as named styles: filled buttons 15px / 600; outlined and text buttons 15px / 500; chip labels 13px / 500; app-bar and dialog titles 20px / 600; bottom-navigation labels 10px / 600 selected and 10px / 400 unselected (11px in dark); tab labels 14px / 600 and 14px / 400.

**Where handwriting is applied, as seen in the code.** Note-card titles use `handwriting-body`, in both list and grid layouts. Note-card timestamps use `handwriting-caption`. The body preview on a grid card is marked handwritten. Everything in the theme — buttons, chips, inputs, navigation, dialogs — is Inter. The handwritten wordmark is a brand commitment in PRODUCT.md; the declared uses of `handwriting-display` (wordmark, hero headings) and `handwriting-title` (screen titles) were not among the sources read.

**Chinese.** The handwriting family carries its own Chinese face: Ma Shan Zheng is registered inside the Caveat family and listed as the per-glyph fallback, so Chinese in a handwritten title stays handwritten. No CJK fallback is declared for Inter in the sources read (`pubspec.yaml` bundles Inter, Caveat, Ma Shan Zheng and RobotoMono), so Chinese UI text uses whatever the platform supplies.

**Drift in the ramp (not a rule).** Inter is bundled as Regular (400), SemiBold (600) and Bold (700) only. `display` and `display-warm` ask for 800, for which no file exists, so the weight that actually renders is not the one declared. The same gap exists for 500: link, the outlined and text button labels, chip labels and three Material label/title steps ask for it, and no Inter 500 file is declared. The handwriting faces are each a single file registered under weights 400–700, so their weight numbers are aliases rather than real cuts.

### Named Rules

**The Two Voices Rule.** Inter speaks for the interface; handwriting speaks for the note. Note titles, note timestamps and the preview on a sticky note are handwritten. Buttons, labels, navigation, settings and body copy are Inter.

**The Handwriting Weight Rule.** Handwritten styles stay at 500 (titles, captions) or 400 (note body). Heavier weights are not used: the engine's per-glyph fallback was observed to skip Ma Shan Zheng at 600 on Android, which dropped Chinese back to the plain UI font.

## Layout

The spatial model is a single phone column on a 4 px grid. Sizes come from one scale — 2, 4, 8, 12, 16, 20, 24, 32, 40, 48 — with short aliases (`xs` 4, `sm` 8, `md` 16, `lg` 24, `xl` 32) and three presets: screen padding (16), section gap (24), item gap (8).

What the components fix:

- **Screen edges:** 16 horizontally — screen padding, card margins, settings groups, list tiles.
- **Cards:** a Material `Card` carries a 16 × 8 outer margin; `CardContainer` pads 16 inside.
- **Settings groups:** 16 margin left and right, 4 padding top and bottom; rows have 12 vertical padding and 12 at each end; dividers are inset 12 from each side.
- **Sticky notes:** 14 inner padding, 12 at the bottom.
- **Empty states:** 32 horizontal padding; 16 between badge and title, 8 between title and subtitle, 24 before the button.

Note lists come in two layouts, list and grid; the grid is staggered (`flutter_staggered_grid_view`). Column counts and any breakpoints are not in the sources read, so none are recorded. Layouts must survive the system's largest text scale (PRODUCT.md).

**Drift (not a rule).** PRODUCT.md commits to touch targets of at least 48 × 48 dp and `AppSpacing.buttonHeight` is 48, but `AppSpacing.minTouchTarget` is 44. The 48 dp figure is the goal recorded here; the 44 constant is not.

## Elevation & Depth

This is a flat system with one piece of real depth. Elevation never tints a surface — `surfaceTintColor` is transparent on every themed surface (card, FAB, navigation bar, dialog, bottom sheet, popup menu) — so a raised thing keeps its colour. Ordinary cards and inputs are separated by their fill and, where grouping matters, by a 1 px warm border; the theme's own comment for cards reads "soft shadow, no hard border". The one element that visibly sits above the desk is the sticky note, which carries a two-layer warm shadow: a tight contact shadow under the edge and a wider diffuse one, offset down and to the right. A page push adds its own shadow while it moves (see Components → Motion). The high-contrast themes flatten cards (elevation 0) and draw 2 px borders instead.

Two caveats on what is declared versus what paints:

- **In light mode the general shadows paint nothing.** `shadow-light` and `shadow-medium` are six-digit Dart literals (`Color(0x1A1008)`, `Color(0x2A2018)`), so their alpha is 0. That makes `AppShadows.sm`, `md`, `lg` and `xl` — and the light `Card`'s elevation shadow, which uses the same ink — invisible, so plain cards and anything styled with those steps are flat in light mode. Still visible in light mode: the sticky note's paper shadow, the moving page shadow, and the shadows Flutter draws for its own elevated surfaces (dialogs, popup menus, bottom sheets), which the theme gives no shadow colour of their own and so keep Flutter's default. The FAB is the exception: it casts no visible shadow in the build — on the phone the desk colour begins directly under its edge. The dark-theme shadows (12.5 % black) do paint. The values below are recorded as they are, not as a working elevation system.
- **Flutter's `blurRadius` is not a CSS blur radius.** The values below are the Dart numbers written in CSS order (offset x, offset y, blur); a browser renders the blur wider than Flutter does for the same number.

### Shadow Vocabulary

- **paper** (`3px 6px 16px #78644226, 1px 2px 4px #7864421F`): sticky-note cards in light mode.
- **paper-dark** (`3px 6px 16px #00000020, 1px 2px 4px #00000020`): sticky-note cards in dark mode.
- **sheet lift** (`0 -10px 28px rgba(0,0,0,0.26)`): cast upward by a page while it is being pushed; it moves with the page.
- **card press** (`0 4px 12px #8B7CE80C`): added under a tappable `CardContainer` while it is pressed.
- **sm** (`0 1px 4px #1A100800`), **md** (`0 2px 12px #1A100800`), **lg** (`0 4px 20px #2A201800`), **xl** (`0 8px 24px #2A201800`): the declared light-mode steps. Alpha is 0 — they paint nothing.
- **sm-dark** (`0 1px 4px #00000020`), **md-dark** (`0 2px 8px #00000020`), **lg-dark** (`0 4px 16px #00000020`), **xl-dark** (`0 8px 24px #00000020`): the dark-mode steps.

### Named Rules

**The Paper Edge Rule.** A sticky note has no border. Its colour block plus the two-layer warm shadow is the edge.

**The No Tint Rule.** Elevation never changes a surface's colour: `surfaceTintColor` is transparent on every themed surface. Depth is shown by shadow or by a 1 px border, never by tint.

## Shapes

Form language is generous and rounded — no square corners on any themed surface — with one deliberate exception: the sticky note takes the smaller 12 px radius of a real Post-it instead of the 20 px of a UI card.

The radius scale and where each step lands:

- **8 px** (`xxs`): tag badges and other small rounded elements.
- **12 px** (`xs`): sticky notes, chips and badges, outlined and text buttons, snack bars, tooltips, the top corners of an image header on a sticky note.
- **16 px** (`sm`): inputs, filled and tonal buttons, list-layout thumbnails.
- **20 px** (`md`): cards, list tiles, popup menus, settings groups, the empty-state badge.
- **24 px** (`lg`): dialogs, the FAB, the drawer's trailing edge.
- **28 px** (`xl`): bottom sheets, top corners only.
- **Pill** (`9999`): light-theme chips. (The navigation-bar indicator is Material's default stadium; the theme sets its colour, not its shape.)
- **Off the scale:** 4 px on a loading card's skeleton bars.

Borders:

- **1 px Warm Border:** inputs, settings groups, list-layout note cards, dark-theme chips.
- **None:** plain cards, light-theme chips, sticky notes.
- **2 px:** everything bordered in the high-contrast themes (cards, inputs, buttons, chips, dialogs, sheets), with pure black or pure white lines.

Tilt: sticky notes are tilted by a six-value cycle in radians — −0.032, 0.024, −0.018, 0.03, −0.026, 0.021 (about −1.8°, 1.4°, −1.0°, 1.7°, −1.5°, 1.2°) — chosen by list index, so a note's tilt is stable between rebuilds and never random.

Circles: switch thumbs. The tinted container behind a settings icon is not one shape: 32 px circles on the plain rows (版本, 隐私政策, 服务条款), 32 px rounded squares on the two destructive rows (退出登录, 删除账号), and 40 px rounded squares on the rows that carry a switch (主题, 减少动画). Three shapes on one screen — recorded as found, not as a rule.

## Components

### Buttons

Soft-cornered, quiet and purple-led; a press gives slightly.

- **Shape:** generously rounded for filled and tonal (16 px); a little tighter for outlined and text (12 px).
- **Primary (FilledButton):** Soft Periwinkle Purple fill, On-Primary White label, padding 14 × 24, label Inter 15 px / 600. Disabled: Warm Disabled Grey fill with Warm Muted Ink label.
- **Tonal (FilledButton.tonal):** the quieter call to action — the empty-state button, a retry. Same 16 px corners. Its fill and label are Material's `secondaryContainer` and `onSecondaryContainer`, which are derived from the seed and not pinned to a token in the theme.
- **Outlined:** Soft Periwinkle Purple label, a 1 px outline in the derived `colorScheme.outline`, padding 14 × 24, label 15 px / 500.
- **Text:** Soft Periwinkle Purple label, padding 10 × 16, label 15 px / 500.
- **Hover / Focus / Press:** the theme pins no hover, focus or pressed colours for buttons; they are Material's defaults. Press feedback for anything wrapped in `PressableScale` is a spring to 0.97 scale (see Motion).
- **Dark theme:** filled buttons take Light Periwinkle with a Deep Navy label.

### Inputs / Fields

- **Style:** filled with Warm Input Fill, 1 px Warm Border, 16 px corners, content padding 14 × 16, body type (Inter 15 px / 400 / 1.47). Hints in Warm Muted Ink.
- **Focus:** the border grows to 2 px in Soft Periwinkle Purple at alpha 120 (about 47 %).
- **Error:** 1 px in the theme's error colour (Material's derived error, not the `error` token); 2 px when focused.
- **Dark:** Navy Input Fill, Navy Border, focus at alpha 150.
- **Search field:** no dedicated search-field widget is among the sources read. `AppIcons.search` exists in the icon table, and a search field would inherit this input theme; nothing more specific is recorded.

### Chips

- **Style (light):** Cool Chip Grey background, Slate Ink label 13 px / 500, no border, pill shape, padding 6 × 16.
- **Selected:** Lavender Tint background, Deep Accent Purple label.
- **Dark:** different in shape — Navy Input Fill with a 1 px Navy Border and 12 px corners, padding 4 × 12. Selected uses Dark Lavender Container with Lavender Tint Border as the label colour.
- The two themes disagree on chip shape (pill without border, against 12 px with a border). This is recorded as found.
- The home screen's filter chips carry an icon before the label: `AppIcons.noteBlank` on "all notes", and on a tag's chip an icon guessed from the tag's name (`lightbulb` for ideas, `briefcase` for work, `plant` for personal, `bookOpen` for reading, `airplane` for travel, `checkCircle` for to-dos), cycling through the same set when the name says nothing. Selected or not, the icon takes the label's colour.
- The tag chips drawn on note cards come from a widget outside the sources read; their look is not recorded here.

### Navigation

- **Bottom navigation:** Warm Card White background, no elevation. Two variants are themed: the Material 3 `NavigationBar` (height 56, a Lavender Tint indicator behind the selected icon, 10 px labels) and the older `BottomNavigationBar` (11 px labels). Selected item and label (600): Soft Periwinkle Purple. Unselected item and label (400): Warm Brown-Grey Ink.
- **Dark:** Navy Card background, height 64, 11 px labels. Light and dark disagree on height and label size.
- **Icons:** the icon table holds four regular/fill pairs for navigation — `notes` (house), `compose` (pen), `ai` (chat circle), `settings` (gear). The filled cut marks the selected destination.
- **App bar:** Warm Cream, no elevation at rest (0.5 when scrolled under), left-aligned title Inter 20 px / 600 in Slate Ink. About twenty pages make the bar transparent so that it melts into the paper.
- **System status bar:** the theme, not the page, decides its icons — dark on the light themes, light on the dark ones. An app bar left to judge for itself reads "transparent" as dark and asks for white icons (`status_bar_style_test.dart`).
- **Tabs:** Soft Periwinkle Purple label 14 px / 600 and an indicator under the label only; unselected label Warm Brown-Grey Ink 14 px / 400.
- The navigation widget itself is not among the sources; only its theme and its icon pairs are.

### Cards / Containers

- **Corner Style:** gently curved (20 px).
- **Background:** Warm Card White.
- **Shadow Strategy:** declared at elevation 1 with no tint; the shadow is invisible in light mode (see Elevation & Depth).
- **Border:** none on a plain card. A settings group adds a 1 px Warm Border.
- **Internal Padding:** 16 in `CardContainer`; a Material `Card` has a 16 × 8 outer margin instead.
- **Press:** a tappable `CardContainer` adds the card-press shadow and eases there over `standard` with `arrive`.
- **Related surfaces:** dialogs 24 px; bottom sheets 28 px on the top corners only; popup menus 20 px at elevation 4; floating snack bars at 12 px, inverted (Navy Card with Pale Lavender White text in light, the reverse in dark); list tiles 20 px with 16 × 4 content padding.

### Settings Rows

- **Group:** 20 px corners, 1 px Warm Border, 4 px vertical padding, 16 px side margin. Rows are separated by a 0.5 px divider inset 12 px from each side.
- **Row:** 12 vertical padding; 12 at each end; a tinted container holding an 18 px icon (a 32 px circle on rows built from `SettingsItem`; see Shapes for the other two shapes that appear); a 12 px gap; the title in body type; an optional subtitle in caption type 2 px below; an optional trailing widget after an 8 px gap.
- **Icon circle:** the fill is the row's accent at 12 % (15 % in dark) and the icon is drawn in that accent — Soft Periwinkle Purple unless a row overrides it.
- **Press:** the row scales to 0.98 over `fast` with `arrive`, under an 8 % purple ink splash clipped to 8 px corners. This row takes `AppAnimation.fast` directly rather than asking `context.motion`.
- **Destructive row:** icon circle and title in the theme's error colour, subtitle at 70 % of it. That colour is Material's derived error, not the `error` token.
- **Group header:** 13 px / 600 in the caption colour, padding 16 / 16 / 16 / 6. Section headers are 13 px / 600 in Soft Periwinkle Purple, padding 16 / 16 / 16 / 8.

### Sticky-Note Card (signature)

The note as a sheet of paper on the desk. In the grid layout each note is a `PaperSurface` carrying the paper tokens; in the list layout the same widget is a straight, bordered card.

- **Tone:** the six-sheet cycle by list index, resolved through `PaperTokens.of(context).toneFor(index, brightness)`. A selected note takes Lavender Tint. A note with an image takes the plain card colour beneath its image. A note's own colour setting selects one of the six by name — yellow and orange to Morning-Thoughts Yellow, peach and pink to Salmon Pink, green to Plant-Care Mint, blue, lavender and purple to Lavender Note — or, for any other colour, a 40-alpha wash.
- **Corner:** a real Post-it (12 px), not a rounded card.
- **Edge:** no border; the colour block plus the two-layer warm shadow.
- **Tilt:** the six-value cycle, by list index.
- **Inner Padding:** 14 top and sides, 12 bottom.
- **Ink:** title in Slate Ink, preview text in Warm Brown-Grey Ink, timestamp in Warm Muted Ink. In dark: Pale Lavender White, Muted Lavender Grey, Dim Lavender Grey.
- **Type:** title `handwriting-body` (22 px / 500; up to 4 lines in the grid, 2 in the list). Preview up to 4 lines and handwritten in the grid. Timestamp `handwriting-caption` (17 px / 500).
- **State icons:** the pin (`AppIcons.pinFilled`) in Soft Periwinkle Purple, 14 px in the grid and 16 px in the list, before the title; the lock (`AppIcons.lock`) in Warm Muted Ink at alpha 150, 12 px and 14 px.
- **Footer:** timestamp at the left; a small hand-drawn doodle at the right in Warm Brown-Grey Ink at alpha 150 — a book, a bulb, a sprout or a heart. The doodle is decorative and excluded from semantics, and is keyed to the note id so it does not change between rebuilds. There is no star in the set: in that corner a star is the favourite state.
- **Tags:** a row of tag chips 8 px above the footer when the note has tags.
- **Press:** purple ink splash at alpha 20 and highlight at alpha 10. A long press gives a medium haptic.
- **Image notes:** the image is clipped to 12 px top corners, 80–200 px tall. In the list layout a 56 × 56 thumbnail sits at the right with 16 px corners.
- **List layout:** Warm Card White, 20 px corners, 1 px Warm Border, padding 16 × 14, preview up to 3 lines, timestamp right-aligned, no doodle, no tilt.
- **Dark:** the tone is the dark wash over Navy Card and the shadow is `paper-dark`; tilt is unchanged.

Two points about this card are open, and neither is a rule. The selection ring is drawn by `PaperSurface` ("the periwinkle selection ring"), whose colour and width are outside the sources read. And the footer doodle sits in the corner where real state appears: a starred note shows its star bottom-right, where every other note shows a doodle, in much the same weight. The doodle set once had a star of its own, which made the two indistinguishable; it no longer does, but the decoration still shares the corner with the favourite star.

### Empty State and Loading Card

- **Empty state:** centred, 32 px side padding. A 72 px badge with 20 px corners in Lavender Badge Tint holds a 32 px icon in Lavender Badge Ink; 16 px below, the title in `title` type and Warm Brown-Grey Ink; 8 px below that, the subtitle in `caption` type with 1.5 line-height in Warm Muted Ink; 24 px below that, a tonal button. It fades in over `standard`.
- A second look exists, on the compose tab: a peach badge with an orange `AppIcons.article` and no button. Recorded as found.
- **Loading card:** a Material `Card` holding white skeleton bars with a warm shimmer sweep (1440 ms per cycle). The sweep is a loop, not a transition, and is not started when motion is reduced.
- **Sync badge:** a 16 px status icon with an optional 12 px label — Success Green and `AppIcons.cloudDone` when synced, Warning Amber and `AppIcons.cloudUpload` when pending, Error Red on a conflict. On a note that has not synced, the badge is `AppIcons.cloudOff` in Warning Amber with the label 未同步.

### Icons

One family, one stroke weight, one table.

- **Family:** Phosphor line, the `Regular` cut. Every icon the app draws is one line in `AppIcons`, by name.
- **Names mean, not look:** a name is what the icon means (`delete`), not what it looks like (`trash`).
- **Filled is a state:** `…Filled` is the on state of a toggle only (star, pin, bookmark, mic and the like) and always sits next to its `Regular` pair. It is never used on its own as decoration.
- **Bold is high contrast only:** `Bold` appears twice, for the two high-contrast theme choices (`highContrastLight`, `highContrastDark`), where the heavier stroke is the meaning.
- **No Material icons, no direct Phosphor, no emoji:** Material `Icons.*` is not used — it mixed three styles, and some of its code points render as colour emoji on Samsung phones. No Phosphor class is used outside `AppIcons`. No emoji or text symbol stands in for an icon: the home filter chips, the task boxes in a note's preview and the sparkle after the wordmark used to be typed emoji and characters, which a Note 9 drew in colour or not at all. `test/design/icon_system_test.dart` keeps all three out, in either escape a symbol can take.
- **The formatting toolbar is in the family too:** its buttons are the family's own text-tool glyphs (`textB`, `textItalic`, `textUnderline`, `textStrikethrough`), with a different one for each heading level (`textHOne`, `textHTwo`, `textHThree`) — never letters typed in the interface font.
- **A menu says which option is current:** in the home ⋮ menu the sort rows are told apart by what they sort by (`schedule` for updated time, `calendarToday` for created time, `sort` for title, `tune` for a custom order), and the current sort carries `check`.
- **Adding one:** check the table first; then add one line and use it everywhere.
- **Size and colour:** 24 px by default in Warm Brown-Grey Ink; Soft Periwinkle Purple where the primary icon theme applies, such as app-bar actions. Observed sizes: 32 in the empty-state badge, 18 in the settings icon circle, 16 in the list-layout pin and the sync badge, 14 in the grid-layout pin, 12 in the grid-layout lock, 36 on the error card.

Drift, not a rule: the home screen's sort menu shows six items — by updated time, by created time, by title, custom — and all six carry the same `sort` icon.

### Motion

Motion is paper behaviour, built from four durations, two curves and two springs declared once in `AppAnimation`:

| Token | Value | For |
| --- | --- | --- |
| `fast` | 120 ms | Immediate feedback: a press, a toggle, an arrow turning, text swapping |
| `standard` | 220 ms | A routine state change: a sheet, a card settling, a tab switch, a fade |
| `emphasized` | 320 ms | A page change |
| `expressive` | 480 ms | The one authored move a screen is allowed. In use as the period of the sync icon's turn while a sync runs |
| `arrive` | `cubic-bezier(0.05, 0.7, 0.1, 1)` | Coming into place: quick to start, then a long glide to rest |
| `depart` | `cubic-bezier(0.3, 0, 0.8, 0.15)` | Leaving: hangs, then goes |
| `press` | spring, mass 1, stiffness 1400, damping 90 | Pressing down; over-damped, so nothing wobbles under a thumb |
| `settle` | spring, mass 1, stiffness 500, damping 31 | Letting go; just short of critical damping, so a thing lands with one small dip. About 450 ms to rest |

How it is used:

- **A press gives slightly.** `PressableScale` scales to 0.97 on the `press` spring and returns on `settle`. The settings row does its own 0.98 over `fast`.
- **The first screenful of notes lands.** `StaggeredCardEntrance` gives the first eight cards of a list, and only those, one small landing each: a card is there and readable from its first frame, 3.5 % large and 10 px low, and comes to rest on the `settle` spring, 24 ms after the one before it. Cards built later by scrolling are simply there.
- **"Saved" lands like a stamp.** `LandIn` starts 1.25× large and a few px high, and comes down on the `settle` curve fitted into `fast`. It plays once, when inserted: on the editor's saved mark.
- **A sheet is lifted to open it.** Pushing a page: the new page rises 24 px from below at 0.96 scale and fades in, casting the sheet-lift shadow, over `emphasized`. The page underneath scales back to 0.985 and dims by 8 %. Back is the same move in reverse over `standard`. iOS keeps its own transition.
- **Tab to tab.** The outgoing page is gone by 45 % (`depart`), the incoming one starts at 35 % (`arrive`), `standard` each way. Nothing moves.
- **An overlay rises.** An overlay route slides up from the bottom edge over `emphasized`, behind a 54 % black barrier.
- **Loops are not transitions.** The loading shimmer's 1440 ms sweep is the one duration outside the tokens, and under reduced motion it is simply not started.

"减少动画" (reduce motion) is served three ways:

1. The in-app switch is reported to Flutter (`AppBinding` carries it into the binding), so every duration-based animation — sheets, menus, switches, ink, every `Animated*` widget — is over in a frame or two. `test/core/theme/animation_config_test.dart` shows a 300 ms fade taking at least fifteen frames without the switch and at most three with it.
2. Authored motion asks `context.motion`: with the switch on, every duration is zero and every curve is linear, so a move becomes a change of state. Duration-based widgets take `AppAnimation` as it is.
3. The answer is kept on disk (`reduce_motion`: `on`, `off` or `system`); unset, it follows the system's remove-animations setting. The row's subtitle says what happens — 显示全部动画, 动画已减少, 跟随系统设置. Once the switch has been toggled the row offers only on or off; there is no way back to following the system. Recorded as a gap.

Under reduced motion nothing scales: a press dims to 72 % opacity instead, a page push becomes a short fade, the notes do not land, the sync icon does not turn, and `LandIn` is simply there.

## Do's and Don'ts

### Do:

- **Do** draw every icon through `AppIcons` — Phosphor `Regular`, one stroke weight — and name it by what it means (`delete`, not `trash`).
- **Do** use `…Filled` only as the on state of a toggle, beside its `Regular` twin.
- **Do** take every duration, curve and spring from `AppAnimation`, and ask `context.motion` for authored motion such as staggers, springs and page transitions.
- **Do** give a sticky note its tone from the six-sheet cycle through `PaperTokens.of(context).toneFor(index, brightness)`; that is also what produces the dark washes.
- **Do** write note titles and note timestamps in the handwriting family, and keep everything the interface says in Inter.
- **Do** take radii from `AppRadius` (16 px for inputs and filled buttons, 20 px for cards, 12 px for sticky notes) and spacing from `AppSpacing`.
- **Do** make "减少动画" calm every new animation: loops do not start, and moves become changes of state.
- **Do** mark decorative drawing as decorative, the way the sticky-note doodle is excluded from semantics.

### Don't:

- **Don't** use Material `Icons.*`, or a Phosphor class anywhere outside `AppIcons`.
- **Don't** use `…Filled` on its own as decoration, or `Bold` outside the two high-contrast theme choices.
- **Don't** declare a duration, curve or spring of your own.
- **Don't** put a border on a sticky note; its colour block and warm shadow are the edge.
- **Don't** set a handwritten style above weight 500.
- **Don't** set UI controls — buttons, navigation, settings rows — in the handwriting family.
- **Don't** tint a surface to show elevation.
- **Don't** set the status bar's icon colour per page, or leave it to an app bar's background: it comes from the theme.
- **Don't** hard-code a paper tone for dark mode; resolve it through `toneFor`.
