# Compose Feature Test Plan — v2.7.4 Real Device

## Feature Overview

AI Compose 4-stage pipeline: Select Notes → Cluster → Outline → Draft → Style Adapt → Save

## Test Categories

### A. Normal Flow (Happy Path)
1. Open Compose tab → verify hero card and empty state
2. Tap "Start Composing" → note selector opens
3. Select 1-2 notes → proceed to clustering
4. Wait for AI clustering → verify clusters display
5. Select clusters → generate outline
6. Verify outline sections display
7. Expand to draft → verify streaming content
8. Style adaptation → verify content changes
9. Save as note → verify saved in notes list

### B. Edge Cases — Input Validation
10. Open note selector with 0 notes → verify empty state
11. Select exactly 10 notes (max limit) → verify UI
12. Try to select 11th note → verify limit enforced
13. Notes exceeding 100K chars total → verify limit enforced
14. Select only 1 note → verify single-note compose works
15. Select notes with empty content → verify handling

### C. Error Scenarios
16. Start compose with no network → verify error state
17. AI clustering fails (server error) → verify retry button
18. Outline generation fails → verify error + retry
19. Draft streaming interrupted → verify partial content preserved
20. Save fails (storage full / DB error) → verify error message

### D. Navigation & Interruption
21. Back press during clustering → verify cancel + cleanup
22. Back press during outline editing → verify state preserved
23. Back press during draft streaming → verify cancel stream
24. Switch tabs during active compose → verify state
25. Rapid tap "Start Composing" → verify no duplicate sheets

### E. UI/UX Specifics
26. Verify loading skeletons display correctly
27. Verify cluster selection checkboxes work
28. Verify outline reordering (drag handles)
29. Verify outline title editing dialog
30. Verify word count updates in compose editor
31. Verify scroll-to-bottom during streaming
32. Verify compose history list after successful compose
33. Tap existing composition → verify content preview
34. Copy button in content preview → verify clipboard

### F. Localization
35. Verify all Compose UI in Chinese locale
36. Verify error messages are localized
