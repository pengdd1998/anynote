/// Built-in template data for seeding the note_templates table on first run.
class TemplateData {
  final String name;
  final String content;

  const TemplateData({required this.name, required this.content});
}

class SeedTemplates {
  static const builtIn = [
    TemplateData(
      name: 'Meeting Notes',
      content: '''# Meeting Notes
## Date: {{date}}
## Attendees
-
## Agenda
1.
## Action Items
- [ ]
## Notes

''',
    ),
    TemplateData(
      name: 'Daily Journal',
      content: '''# Daily Journal -- {{date}}
## Gratitude
1.
## Highlights
-
## Tomorrow's Focus
-
''',
    ),
    TemplateData(
      name: 'Project Notes',
      content: '''# Project:
## Status
## Key Decisions
-
## Current Blockers
-
## Next Steps
1.
''',
    ),
    TemplateData(
      name: 'Reading Notes',
      content: '''# Reading Notes
## Book/Article:
## Key Takeaways
1.
## Quotes
>
## My Thoughts

''',
    ),
    TemplateData(
      name: 'Weekly Review',
      content: '''# Weekly Review -- {{date}}
## Accomplishments
-
## Challenges
-
## Lessons Learned
-
## Next Week Goals
1.
''',
    ),
  ];
}
