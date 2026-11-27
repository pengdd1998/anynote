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

## Status (2026-11-27)

- Built on `design/home-editor`: `9687ea6`, `f49bf77`, `697f347`, `ca273ae`, `eefadf3`, `1027405`, on top of `design/icons-and-motion` at `bd97dad`. Not merged, no PR, no release.
- Local gate at `1027405`, code frozen: analyze 0 error / 0 warning (306 infos, the branch's standing count); 3,448 tests passed. Each guard added in the pass fails with its defect put back.
- The finish review ran on twelve captures of `ca273ae`: disposition `fix`, twenty defects, and phase 1's five fixes judged fixed. Fourteen of the twenty closed in `eefadf3`. A fifteenth thing was found on the phone, not by the review: a hold on the floating "+" opened a new note, because the button's own tooltip won the long press. Closed in `1027405`.
- Seen on the Note 9: twenty-one captures of `eefadf3` — home in grid and list, both menus, the note page, the editor, Settings, light and dark — and two of `1027405`, in `.impeccable/review/phase2/round3/` (README there says what each shows). "编辑", "完成" and the hold on "+" were used, not only looked at.
- The verdict pass on these 23 captures (`round3/verdict.md`): **`disposition: fix`.** Thirteen of the fourteen closed defects are fixed, by measurement. It held back defect 3 on one capture — the dark editor menu, taken 1.5 s after the menu opened, before the fade came in — and it named what is new: the status bar at 2.83:1 under a modal sheet, the dark tab bar 21 px taller than the light one, two kinds of modal, a green "current" mark in the theme dialog, a third purple in the Settings rows, and no two-paragraph note to judge acceptance point 3 by.
- `4f61d30` answers the held-back item: the fade is painted where the menu is at the moment of painting, on the menu's edge from its first frame. Gate locally: analyze 0 / 0, 3,449 tests passed and one wall-clock timing test that passes alone. Installed on the Note 9 in the background at 11:45 and **not yet opened there**. The session on the phone stopped on 2026-11-27 at 11:26, with the owner using it; the captures that would close the verdict's gaps are still owed.
- Left open from the review for the owner to decide: 8, 14, 16, 17, 19, 20, and the second half of 13.
- New from the verdict, for the owner: the status bar under a sheet (keep the scrim off that strip, or light icons while a scrim is up); the green current mark in the theme dialog; the Settings rows' icon ink (#7C6AC4), a third purple.
- Seen on the phone and not touched: the grid/list choice is not remembered across tabs; opening a note in the editor saves it again without an edit.
