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

## Status (2026-11-27, night)

- Built on `design/home-editor`: `9687ea6`, `f49bf77`, `697f347`, `ca273ae`, `eefadf3`, `1027405`, `4f61d30`, `37b3a29`, `f5fdb73`, `783c0b3`, `7cb01de`, on top of `design/icons-and-motion` at `bd97dad`; plus one fix outside the pass, `1614e03`, the editor's two modes. Not merged, no PR, no release.
- Gate at `7cb01de`, code frozen: analyze 0 error / 0 warning (304 infos, the branch's standing count); 3,465 tests passed. Every guard added in the pass fails with its defect put back.
- The finish review of `ca273ae`: `fix`, twenty defects; fourteen closed in `eefadf3`, the hold on the floating "+" found on the phone and closed in `1027405`.
- The verdict on 23 captures of those builds: `fix` — thirteen fixed by measurement, one captured before the menu's fade came in. That led to `4f61d30`.
- The verdict on 31 captures and three recordings of `4f61d30`: `fix` — the fade is on both menus at rest, the corner speck is gone, point 3 passes on a real two-paragraph note; two unreadable elements remain: the pin on a pinned card in dark (1.45–1.60:1) and the status bar under the new-note sheet in light (2.83:1). That led to `37b3a29`, `f5fdb73` and `783c0b3`.
- On the phone, `783c0b3`: the pin in dark is #B6ADF1 (about 4.1:1). The status bar fix did not work — the page's app bar carries a region one layer deeper, and that is the one Flutter takes — so `7cb01de` puts the style above the whole app, and the boot test now asserts what the system is given.
- **Not yet on the phone**: `7cb01de` (built and downloaded; the phone was in the owner's hands). Owed: the sheet in light with the status bar light; the pinned card in the dark list and its star on the note page; a recording of a menu opening, for the fade on the growing edge; the editor in plain text on a rich note. Then the captures go back to the independent reviewer — it has said `fix` twice, and each time on things the phone or the frames showed.
- Left open from the review for the owner to decide: 8, 13 (second half), 14, 16, 17, 19, 20. New from the second verdict: a card's sheet colour follows its position, not the note (bears on 19); the theme dialog marks the current row in green; the Settings rows' icon ink is a third purple.
- Seen on the phone and not touched: the grid/list choice is not remembered across tabs; the test note's counts rose across sessions that mixed plain-text mode (a clean open does not do it; cause not found).
