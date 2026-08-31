import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/compose/domain/post_template.dart';
import 'package:anynote/features/compose/domain/prompt_builder.dart';

/// A template with a distinctive fragment used to assert prompt injection.
PostTemplate _templateWithMarker() => PostTemplate(
      id: 'tpl-1',
      name: 'Marker Template',
      description: '',
      systemPrompt: 'TEMPLATE_FRAGMENT_MARKER',
      structureHint: 'A -> B -> C',
      toneHint: 'cheerful',
      isBuiltIn: true,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  late PromptBuilder builder;

  setUp(() {
    builder = PromptBuilder();
  });

  // ---------------------------------------------------------------------------
  // buildClusterPrompt
  // ---------------------------------------------------------------------------

  group('buildClusterPrompt', () {
    test('includes the topic in the prompt', () {
      final result = builder.buildClusterPrompt(
        ['note one', 'note two'],
        'Machine Learning',
      );
      expect(result, contains('Machine Learning'));
    });

    test('includes all note contents with index labels', () {
      final result = builder.buildClusterPrompt(
        ['First note', 'Second note', 'Third note'],
        'topic',
      );
      expect(result, contains('[0] First note'));
      expect(result, contains('[1] Second note'));
      expect(result, contains('[2] Third note'));
    });

    test('includes JSON output schema with clusters key', () {
      final result = builder.buildClusterPrompt(
        ['a note'],
        'topic',
      );
      expect(result, contains('"clusters"'));
      expect(result, contains('"name"'));
      expect(result, contains('"theme"'));
      expect(result, contains('"note_indices"'));
      expect(result, contains('"summary"'));
    });

    test('handles single note', () {
      final result = builder.buildClusterPrompt(
        ['Only note'],
        'single topic',
      );
      expect(result, contains('[0] Only note'));
    });

    test('handles empty note list', () {
      final result = builder.buildClusterPrompt(
        [],
        'empty topic',
      );
      // Should not throw; prompt body simply has no note entries.
      expect(result, contains('empty topic'));
      expect(result, contains('content organizer'));
    });

    test('handles notes with special characters and unicode', () {
      final result = builder.buildClusterPrompt(
        ['Note with "quotes" and <brackets>', 'Unicode: \u4f60\u597d\u4e16\u754c'],
        'special chars',
      );
      expect(result, contains('"quotes"'));
      expect(result, contains('\u4f60\u597d\u4e16\u754c'));
    });

    test('injects the template prompt fragment when provided', () {
      final result = builder.buildClusterPrompt(
        ['a note'],
        'topic',
        template: _templateWithMarker(),
      );
      expect(result, contains('TEMPLATE_FRAGMENT_MARKER'));
      expect(result, contains('Target format guidance'));
    });

    test('omits the template fragment when no template is given', () {
      final result = builder.buildClusterPrompt(['a note'], 'topic');
      expect(result, isNot(contains('TEMPLATE_FRAGMENT_MARKER')));
    });

    test('separates notes with the kNoteSeparator sentinel', () {
      final result = builder.buildClusterPrompt(
        ['First note', 'Second note'],
        'topic',
      );
      const sep = '\n$kNoteSeparator\n';
      expect(result, contains('[0] First note$sep[1] Second note'));
    });

    test('note separator constant round-trips through join/split', () {
      const notes = [
        'multi-line note\nwith a second line\nand a third',
        'plain note',
        'unicode \u4f60\u597d note',
      ];
      final joined = notes.join('\n$kNoteSeparator\n');
      expect(joined.split('\n$kNoteSeparator\n'), notes);
    });
  });

  // ---------------------------------------------------------------------------
  // buildOutlinePrompt
  // ---------------------------------------------------------------------------

  group('buildOutlinePrompt', () {
    test('includes platform name in the prompt', () {
      final result = builder.buildOutlinePrompt(
        [
          {'name': 'Intro', 'summary': 'Introduction to the topic'},
        ],
        'Xiaohongshu',
      );
      expect(result, contains('Xiaohongshu post'));
    });

    test('includes cluster name and summary for each cluster', () {
      final clusters = [
        {'name': 'Cluster A', 'summary': 'Summary A'},
        {'name': 'Cluster B', 'summary': 'Summary B'},
      ];
      final result = builder.buildOutlinePrompt(clusters, 'Twitter');
      expect(result, contains('Cluster A: Summary A'));
      expect(result, contains('Cluster B: Summary B'));
    });

    test('includes JSON output schema with title and sections', () {
      final result = builder.buildOutlinePrompt(
        [
          {'name': 'C', 'summary': 'S'},
        ],
        'blog',
      );
      expect(result, contains('"title"'));
      expect(result, contains('"sections"'));
      expect(result, contains('"heading"'));
      expect(result, contains('"points"'));
      expect(result, contains('"source_cluster"'));
    });

    test('handles empty cluster list', () {
      final result = builder.buildOutlinePrompt([], 'Medium');
      expect(result, contains('Medium post'));
    });

    test('injects the user topic into the prompt', () {
      final result = builder.buildOutlinePrompt(
        [
          {'name': 'C', 'summary': 'S'},
        ],
        'blog',
        topic: 'My Special Topic',
      );
      expect(result, contains('User topic: My Special Topic'));
    });

    test('omits the topic line when topic is empty', () {
      final result = builder.buildOutlinePrompt(
        [
          {'name': 'C', 'summary': 'S'},
        ],
        'blog',
        topic: '',
      );
      expect(result, isNot(contains('User topic:')));
    });

    test('injects the template prompt fragment when provided', () {
      final result = builder.buildOutlinePrompt(
        [
          {'name': 'C', 'summary': 'S'},
        ],
        'blog',
        template: _templateWithMarker(),
      );
      expect(result, contains('TEMPLATE_FRAGMENT_MARKER'));
    });
  });

  // ---------------------------------------------------------------------------
  // buildExpandPrompt
  // ---------------------------------------------------------------------------

  group('buildExpandPrompt', () {
    test('includes outline title', () {
      final outline = {
        'title': 'My Awesome Post',
        'sections': [],
      };
      final result = builder.buildExpandPrompt(outline, ['source note']);
      expect(result, contains('My Awesome Post'));
    });

    test('includes section headings and points', () {
      final outline = {
        'title': 'Test',
        'sections': [
          {
            'heading': 'Introduction',
            'points': ['Hook the reader', 'State the problem'],
          },
          {
            'heading': 'Solution',
            'points': ['Step one', 'Step two'],
          },
        ],
      };
      final result = builder.buildExpandPrompt(outline, []);
      expect(result, contains('Introduction'));
      expect(result, contains('Hook the reader, State the problem'));
      expect(result, contains('Solution'));
      expect(result, contains('Step one, Step two'));
    });

    test('includes source notes', () {
      final outline = {
        'title': 'Title',
        'sections': [],
      };
      final result = builder.buildExpandPrompt(outline, [
        'First source material',
        'Second source material',
      ]);
      expect(result, contains('First source material'));
      expect(result, contains('Second source material'));
    });

    test('handles missing sections gracefully', () {
      final outline = <String, dynamic>{
        'title': 'No Sections',
      };
      final result = builder.buildExpandPrompt(outline, ['note']);
      expect(result, contains('No Sections'));
      // Should not throw when sections key is absent.
      expect(result, contains('note'));
    });

    test('handles sections with missing points list', () {
      final outline = {
        'title': 'Partial',
        'sections': [
          <String, dynamic>{'heading': 'Only heading'},
        ],
      };
      final result = builder.buildExpandPrompt(outline, []);
      expect(result, contains('Only heading'));
    });

    test('requests natural engaging style', () {
      final outline = {
        'title': 'Title',
        'sections': [],
      };
      final result = builder.buildExpandPrompt(outline, []);
      expect(result.toLowerCase(), contains('engaging'));
    });

    test('injects the user topic into the prompt', () {
      final outline = {
        'title': 'Title',
        'sections': [],
      };
      final result = builder.buildExpandPrompt(
        outline,
        ['note'],
        topic: 'Grow Tomatoes',
      );
      expect(result, contains('User topic: Grow Tomatoes'));
    });

    test('omits the topic line when topic is empty', () {
      final outline = {
        'title': 'Title',
        'sections': [],
      };
      final result = builder.buildExpandPrompt(
        outline,
        ['note'],
        topic: '',
      );
      expect(result, isNot(contains('User topic:')));
    });

    test('injects the template prompt fragment when provided', () {
      final outline = {
        'title': 'Title',
        'sections': [],
      };
      final result = builder.buildExpandPrompt(
        outline,
        ['note'],
        template: _templateWithMarker(),
      );
      expect(result, contains('TEMPLATE_FRAGMENT_MARKER'));
      expect(result, contains('template specification'));
    });
  });

  // ---------------------------------------------------------------------------
  // buildStyleAdaptPrompt
  // ---------------------------------------------------------------------------

  group('buildStyleAdaptPrompt', () {
    test('includes the platform name', () {
      final result = builder.buildStyleAdaptPrompt(
        'Some content here',
        'Instagram',
      );
      expect(result, contains('Instagram'));
    });

    test('includes the full content', () {
      const content = 'This is the original content to adapt.';
      final result = builder.buildStyleAdaptPrompt(content, 'Twitter');
      expect(result, contains(content));
    });

    test('mentions tone, format, and style', () {
      final result = builder.buildStyleAdaptPrompt('content', 'LinkedIn');
      expect(result.toLowerCase(), contains('tone'));
      expect(result.toLowerCase(), contains('format'));
      expect(result.toLowerCase(), contains('style'));
    });

    test('instructs to output adapted content directly', () {
      final result = builder.buildStyleAdaptPrompt('content', 'blog');
      expect(result.toLowerCase(), contains('adapted content'));
    });

    test('handles empty content string', () {
      final result = builder.buildStyleAdaptPrompt('', 'Xiaohongshu');
      expect(result, contains('Xiaohongshu'));
    });

    test('injects the template prompt fragment when provided', () {
      final result = builder.buildStyleAdaptPrompt(
        'content',
        'XHS',
        template: _templateWithMarker(),
      );
      expect(result, contains('TEMPLATE_FRAGMENT_MARKER'));
      expect(result, contains('template specification'));
    });

    test('omits the template fragment when no template is given', () {
      final result = builder.buildStyleAdaptPrompt('content', 'XHS');
      expect(result, isNot(contains('TEMPLATE_FRAGMENT_MARKER')));
    });
  });

  // ---------------------------------------------------------------------------
  // buildRefineSystemPrompt
  // ---------------------------------------------------------------------------

  group('buildRefineSystemPrompt', () {
    test('establishes the editor role and full-output contract', () {
      final result = builder.buildRefineSystemPrompt(null);
      expect(result, contains('post editor'));
      expect(result, contains('FULL updated post'));
    });

    test('injects the template prompt fragment when provided', () {
      final result =
          builder.buildRefineSystemPrompt(_templateWithMarker());
      expect(result, contains('TEMPLATE_FRAGMENT_MARKER'));
    });

    test('omits the template section when no template is given', () {
      final result = builder.buildRefineSystemPrompt(null);
      expect(result, isNot(contains('TEMPLATE_FRAGMENT_MARKER')));
      expect(result, isNot(contains('Template specification')));
    });
  });
}
