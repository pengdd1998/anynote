---
version: 1
slug: "frontend-home-editor"
primary_target: "frontend/lib/features/notes/presentation"
related_targets: ["frontend/lib/core/theme/app_colors.dart","frontend/lib/core/theme/paper_tokens.dart","frontend/lib/core/widgets/paper_surface.dart"]
---

# AnyNote — design system pass 2: the sticky note and the note itself

Scope: the home screen's sticky-note cards, the note page and the editor's status ink, plus the colour tokens those screens read. Visitor mode: Operate (native Android).

## Direction contract

THESIS: A sticky note is for finding a note again, not for admiring it. The paper world stays — six tones, a hand-placed tilt, a handwritten heading, an ink sketch in the corner — and everything that has to be read at a glance moves into the interface's own voice and meets WCAG AA on every sheet.

OWN-WORLD: warm paper desk, six pastel sheets with a warm two-layer shadow and no border; a handwritten title of at most two lines; the preview and the time in the UI face, in an ink mixed from the sheet's own hue; one purple, now deep enough to carry white; status ink (saved, not synced) that reads on paper and on navy. Icons: Phosphor line through `AppIcons`. Motion: unchanged from pass 1.

STORY: the owner opens the app and reads down a screen of notes — title, first lines, time — without slowing down on any card, opens one, and edits. On the way out they see whether it is saved.

FIRST VIEWPORT: the home screen keeps its layout; each card gives its title two lines at most and spends the rest on legible preview.

FORM: `seed: none (pinned)` — the owner's words: 视觉方向「放大个性」, 先做「图标和动效系统」, and on 2026-11-25 for this pass: 「改为采用你的评审建议」(the review's advice: handwriting only on titles; previews and timestamps in the UI face at AA contrast).

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Status (2026-11-27, night — the finish review says `pass`)

- Built on `design/home-editor`: `9687ea6`, `f49bf77`, `697f347`, `ca273ae`, `eefadf3`, `1027405`, `4f61d30`, `37b3a29`, `f5fdb73`, `783c0b3`, `7cb01de`, `ea836ec`, on top of `design/icons-and-motion` at `bd97dad`; plus one fix outside the pass, `1614e03`, the editor's two modes. Not merged, no PR, no release.
- Gate at `ea836ec`, code frozen: analyze 0 error / 0 warning (304 infos, the branch's standing count); 3,466 tests passed, twice. Every guard added in the pass fails with its defect put back.
- The finish review of `ca273ae`: `fix`, twenty defects; fourteen closed in `eefadf3`, the hold on the floating "+" found on the phone and closed in `1027405`.
- Four verdicts by the independent reviewer, each on phone captures it measured itself. 1 (`eefadf3`, `1027405`): `fix`, thirteen of fourteen fixed. 2 (`4f61d30`): `fix` — fade at rest, corner speck, point 3 met; failing: the pin in dark 1.45–1.60:1, the status bar under the new-note sheet in light 2.83:1. 3 (`7cb01de`): `fix` on one number — the pin 4.08:1, the star 8.12:1, the dark status bar 10.69:1, the editor's plain-text mode and the one growing frame all met; the light status bar 3.47:1. 4 (`ea836ec`): **`pass`** — the light status bar 5.34:1 under a sheet and under a dialog, no shade when there should be none, nothing painted in dark; the eight points all met; the clock's dip while a sheet opens (49 ms) and closes (85 ms) measured and not counted: "a moment, not a screen". Reports: `.impeccable/review/phase2/round3/verdict.md`, `verdict-round6.md`, `verdict-round7.md`, `verdict-round8.md`; the captures and recordings of every round are beside them, each named in the folder's README.
- What the last two commits did. `7cb01de`: the status bar's style sits in a layer above the whole app, because a page's app bar carries a region one layer deeper and Flutter takes the topmost one — `f5fdb73` had passed its boot test and done nothing on the phone. `ea836ec`: in the light theme the app paints thirty per cent of black over the status bar's strip while a scrim is up — the phone draws its light icons off-white (#DBDBDA), 3.47:1 on the scrimmed strip; with the shade #D2D2D1 on #50504E, 5.34:1.
- Every fix of the pass has been seen on the phone, on `ea836ec` (`.qa2`), which is left on the home tab, grid, theme on 跟随系统. The fourteen closed defects were measured on the builds that carried them; on `ea836ec` the reviewer did not re-measure each, and found the home captures as before (one "+", one purple, the pin at 4.22:1, four lines of preview).
- Left for the owner, none of it counted against the pass: the review's 8, 13 (second half), 14, 16, 17, 19, 20; the tab bar takes taps under an open sheet (`r7-12` — a sheet belongs to its tab's navigator and its scrim ends above the tab bar; older than the pass); the plain-text field's own look (an inset bordered box, lines 84 px apart against the rich editor's 52; older than the pass); the clock's dip at the two ends of a sheet; the Settings rows' icon ink, a third purple; a card's sheet colour follows its position, not the note.
- Corrected by the fourth verdict: the theme dialog's "current" mark is each option's own colour (mint for 跟随系统, amber #FEF9E7 for 浅色), a design, not a stray colour.
- Not shown in any capture: Chinese note text; a menu growing in light, on the home menu, or with the keyboard up; "未同步" in dark; the pinned card on the other dark sheets; two scrims at once.
- Seen on the phone and not touched: the grid/list choice is not remembered across tabs; the test note "Search Target Note XYZ" keeps blank lines after its text (77 characters / 11 lines, stable since `1614e03`; cause not found).
