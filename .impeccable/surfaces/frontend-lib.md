---
version: 1
slug: "frontend-lib"
primary_target: "frontend/lib"
related_targets: ["frontend/lib/core/theme/app_icons.dart","frontend/lib/core/theme/animation_config.dart","frontend/lib/core/theme/page_transitions.dart"]
---

# AnyNote — design system pass 1: icons and motion

Scope: the whole Flutter client (`frontend/lib`), system layer only. Visitor mode: Operate (native Android).

## Direction contract

THESIS: The paper-and-handwriting world is the product's voice and has so far lived only in the content layer; this pass makes the system layer speak the same language. It refuses the category default of a generic icon set plus scattered, differently-timed animations.

OWN-WORLD: warm paper surfaces, six pastel sticky-note colours, handwritten wordmark and note titles, purple accent. Icons: Phosphor line, one stroke weight, drawn through `AppIcons` everywhere. Motion: paper behaviours — a note lands on the desk and settles, a sheet is lifted to open it, a press gives slightly — with two curves and four durations.

STORY: the owner opens the app, reads a list of notes at a glance, taps one; it lifts like a sheet of paper. They write, save, and see the save land. Nothing waits longer than it must, and "减少动画" makes all of it calm.

FIRST VIEWPORT: unchanged layout on every screen; only the icon family, the timing and the feel of transitions change in this pass.

FORM: `seed: none (pinned)` — the owner's words: 视觉方向「放大个性」, 图标「Phosphor 线框」, 动效「更有表现力」, 先做「图标和动效系统」.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
