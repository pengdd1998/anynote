# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Stack

Flutter (`frontend/`), Go backend (`backend/`). One Flutter code base for Android, iOS, desktop and web stubs; Android is the platform that ships (GitHub Releases, pinned signing). CI builds iOS unsigned.

## Users

People who keep personal notes on their phone and also write for content platforms. The owner is the first user: notes taken on a Note 9 in daily life (meetings, reading, trips, ideas on the road), later turned into posts for 小红书 / 微信公众号 / 知乎 / Medium / WordPress. Chinese is the primary language; the UI also ships English, Japanese and Korean.

## Product Purpose

A private place to capture scattered notes, find them again, and — when wanted — turn a handful of them into a platform-ready article with AI and publish it. Success: a thought is captured in seconds, found in seconds, and a draft can go from notes to a published post without leaving the app.

## Positioning

End-to-end encrypted notes (the server cannot read them) combined with an AI writing pipeline that knows each platform's writing rules and limits, and publishes to that platform from the same app.

## Operating Context

- Mostly one-handed on a phone, in short sessions, often offline or on a poor connection; the local database (SQLCipher) is the source of truth and syncs in the background.
- AI comes from the user's own OpenAI-compatible provider (设置 → LLM 配置) or a small server quota.
- Writing flow: pick notes → topic and target platform → AI clusters → outline → draft → refine → publish sheet (checked against the platform's rules) → publish.

## Capabilities and Constraints

- A personal notes app. No multi-user or collaborative editing; that was removed on purpose.
- Notes, tags, collections, snippets, daily notes, reminders, version history, read-aloud, share links, export and import, trash.
- AI: writing pipeline, chat agent, summaries and tagging.
- Publishing: 小红书, 微信公众号, 知乎, Medium, WordPress, generic webhook.
- Native Android: Material 3 governs structure, navigation and interaction; dark theme and larger text scales must work.
- Undecided: whether iOS is a real target (builds are unsigned).

## Brand Commitments

- Name: AnyNote. The wordmark is handwritten.
- Visual world (confirmed 2026-11-24): warm paper, coloured sticky notes, handwriting. The owner chose to amplify this personality rather than restrain it.
- Icons: one family, Phosphor line icons, drawn through `AppIcons`.
- Motion: expressive, in the paper world's own terms; the "减少动画" setting must work and persist.

## Evidence on Hand

- Device screenshots (Samsung Note 9, release 2.8.10): `qa-screens/`.
- Local renders with the app's real fonts and theme: `frontend/build/design-gallery/` (see `doc/design-review-2026-11.md` §六).
- Design review: `doc/design-review-2026-11.md`.

## Product Principles

1. Paper and handwriting are the product's voice. Amplify them — and whatever carries them must still be readable and tappable.
2. One icon family, one motion system, one component vocabulary; pages differ in content, not in dialect.
3. The user always knows where they stand: saved, syncing, or blocked — and why.
4. It is one person's notes. Every feature is designed for a single owner and their devices.

## Accessibility & Inclusion

- Body and secondary text aim at WCAG AA (4.5:1) in both themes.
- Honour the system's remove-animations setting and the in-app "减少动画" toggle everywhere.
- Touch targets of at least 48×48 dp; layouts survive the system's largest font scale.
