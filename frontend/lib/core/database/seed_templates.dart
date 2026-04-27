/// Built-in template data for seeding the note_templates table on first run.
class TemplateData {
  final String name;
  final String description;
  final String content;
  final String category;

  const TemplateData({
    required this.name,
    required this.description,
    required this.content,
    this.category = 'work',
  });
}

class SeedTemplates {
  static const builtIn = [
    TemplateData(
      name: 'Meeting Notes',
      description: 'Capture meeting discussions and action items',
      category: 'work',
      content: '''# Meeting Notes
## {{date}}

### Attendees
-

### Agenda
1.

### Discussion
-

### Action Items
- [ ]

### Next Meeting

''',
    ),
    TemplateData(
      name: 'Daily Journal',
      description: 'Reflect on your day with gratitude and highlights',
      category: 'personal',
      content: '''# Daily Journal -- {{date}}

## Gratitude
1.
2.
3.

## Highlights
-

## Reflections
-

## Tomorrow's Focus
-

''',
    ),
    TemplateData(
      name: 'Project Plan',
      description: 'Plan project objectives, milestones, and risks',
      category: 'work',
      content: '''# Project Plan

## Objective
-

## Milestones
1.
2.
3.

## Timeline
| Phase | Start | End | Status |
|-------|-------|-----|--------|
|       |       |     |        |

## Resources
-

## Risks & Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
|      |        |            |

## Notes

''',
    ),
    TemplateData(
      name: 'Reading Notes',
      description: 'Summarize books and articles with key insights',
      category: 'personal',
      content: '''# Reading Notes

## Title:
## Author:

### Key Insights
1.
2.
3.

### Quotes
>

### Summary

### My Thoughts

''',
    ),
    TemplateData(
      name: 'Weekly Review',
      description: 'Review accomplishments and plan the week ahead',
      category: 'work',
      content: '''# Weekly Review -- {{date}}

## Accomplishments
-

## Challenges
-

## Lessons Learned
-

## Next Week Goals
1.
2.
3.

## Habit Tracker
| Habit | Mon | Tue | Wed | Thu | Fri | Sat | Sun |
|-------|-----|-----|-----|-----|-----|-----|-----|
|       |     |     |     |     |     |     |     |

''',
    ),
    TemplateData(
      name: 'Brainstorm',
      description: 'Generate and evaluate ideas on a topic',
      category: 'creative',
      content: '''# Brainstorm

## Topic

## Ideas
-

## Evaluation
| Idea | Feasibility | Impact | Effort |
|------|-------------|--------|--------|
|      |             |        |        |

## Top Picks
1.
2.

## Next Steps
- [ ]

''',
    ),
    TemplateData(
      name: 'Blank',
      description: 'Start with a clean slate',
      category: 'personal',
      content: '',
    ),
  ];
}
