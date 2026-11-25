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

## Status (2026-11-25)

- Built on `design/home-editor` (`9687ea6`, `f49bf77`), on top of `design/icons-and-motion` at `bd97dad`. Not merged, no PR.
- Local gate at `f49bf77`: analyze 0 error / 0 warning; 3,427 tests passed. `contrast_test.dart` holds the AA promise; `note_rich_preview_test.dart` and `editor_app_bar_actions_test.dart` each fail with the old behaviour put back.
- Seen on the Note 9, from the first build `9687ea6`: home grid (light), the note page's 编辑, the editor's 已保存.
- **Not yet seen on the phone**, from the final build `f49bf77`: the preview with blank lines closed, the editor's 完成 button, the three status inks, dark theme, list layout. The phone was in the owner's hands during the session.
- **Finish review: not run.** It also owes the verdict pass on phase 1's five fixes.
- Two things were added to the pass while building, both in its own terms and both recorded in the plan: the preview closes blank lines between paragraphs; the editor's save-and-close says 完成.
