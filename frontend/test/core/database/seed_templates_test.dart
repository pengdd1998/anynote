import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/seed_templates.dart';

void main() {
  group('SeedTemplates', () {
    test('builtIn has expected template count', () {
      // Blank template has empty content, exclude from non-empty checks.
      expect(SeedTemplates.builtIn.length, greaterThanOrEqualTo(5));
    });

    test('each template has a non-empty name', () {
      for (final template in SeedTemplates.builtIn) {
        expect(
          template.name,
          isNotEmpty,
          reason: 'Template name should not be empty',
        );
      }
    });

    test('each non-blank template has non-empty content', () {
      for (final template in SeedTemplates.builtIn.where(
        (t) => t.name != 'Blank',
      )) {
        expect(
          template.content,
          isNotEmpty,
          reason: '${template.name} content should not be empty',
        );
      }
    });

    test('template names are unique', () {
      final names = SeedTemplates.builtIn.map((t) => t.name).toList();
      final uniqueNames = names.toSet();
      expect(
        names.length,
        uniqueNames.length,
        reason: 'All template names should be unique',
      );
    });

    test('specific templates contain {{date}} placeholder where applicable',
        () {
      final dateTemplates = SeedTemplates.builtIn.where(
        (t) =>
            t.name == 'Meeting Notes' ||
            t.name == 'Daily Journal' ||
            t.name == 'Weekly Review',
      );
      for (final template in dateTemplates) {
        expect(
          template.content,
          contains('{{date}}'),
          reason: '${template.name} should contain {{date}} placeholder',
        );
      }
    });

    test('non-blank content starts with # (markdown heading)', () {
      for (final template in SeedTemplates.builtIn.where(
        (t) => t.name != 'Blank',
      )) {
        expect(
          template.content,
          startsWith('#'),
          reason:
              '${template.name} content should start with a markdown heading',
        );
      }
    });

    test('TemplateData fields are correct types', () {
      final template = SeedTemplates.builtIn.first;
      expect(template.name, isA<String>());
      expect(template.content, isA<String>());
    });

    test('contains expected template names', () {
      final names = SeedTemplates.builtIn.map((t) => t.name).toSet();

      expect(
        names,
        containsAll([
          'Meeting Notes',
          'Daily Journal',
          'Project Plan',
          'Reading Notes',
          'Weekly Review',
        ]),
      );
    });

    test('Meeting Notes template contains key sections', () {
      final meeting = SeedTemplates.builtIn.firstWhere(
        (t) => t.name == 'Meeting Notes',
      );
      expect(meeting.content, contains('Attendees'));
      expect(meeting.content, contains('Agenda'));
      expect(meeting.content, contains('Action Items'));
    });

    test('Daily Journal template contains key sections', () {
      final journal = SeedTemplates.builtIn.firstWhere(
        (t) => t.name == 'Daily Journal',
      );
      expect(journal.content, contains('Gratitude'));
      expect(journal.content, contains('Highlights'));
    });

    test('Project Plan template contains key sections', () {
      final project = SeedTemplates.builtIn.firstWhere(
        (t) => t.name == 'Project Plan',
      );
      expect(project.content, contains('Objective'));
      expect(project.content, contains('Milestones'));
      expect(project.content, contains('Risks'));
    });

    test('Reading Notes template contains key sections', () {
      final reading = SeedTemplates.builtIn.firstWhere(
        (t) => t.name == 'Reading Notes',
      );
      expect(reading.content, contains('Key Insights'));
      expect(reading.content, contains('Quotes'));
    });

    test('Weekly Review template contains key sections', () {
      final weekly = SeedTemplates.builtIn.firstWhere(
        (t) => t.name == 'Weekly Review',
      );
      expect(weekly.content, contains('Accomplishments'));
      expect(weekly.content, contains('Challenges'));
      expect(weekly.content, contains('Lessons Learned'));
      expect(weekly.content, contains('Next Week Goals'));
    });
  });
}
