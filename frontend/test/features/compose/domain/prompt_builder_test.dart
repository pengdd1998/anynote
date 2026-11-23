import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/compose/domain/post_template.dart';
import 'package:anynote/features/compose/domain/prompt_builder.dart';
import 'package:anynote/features/publish/domain/publish_rules.dart';

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

/// A platform whose brief and limits are distinctive enough to look for.
const _xiaohongshu = PlatformGuide(
  id: 'xiaohongshu',
  name: '小红书',
  titleMax: 20,
  contentMax: 1000,
  maxTags: 10,
  linksAllowed: false,
  guidance: ['像跟朋友讲这周干了什么。', '末尾放 3 到 5 个 #话题。'],
);

const _zhihu = PlatformGuide(
  id: 'zhihu',
  name: '知乎',
  titleMax: 100,
  contentMax: 50000,
  maxTags: 10,
  linksAllowed: true,
);

const _xhsLimits = 'Hard limits: a title of at most 20 characters; '
    'a body of at most 1000 characters; at most 10 tags; no links.';

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
        [
          'Note with "quotes" and <brackets>',
          'Unicode: \u4f60\u597d\u4e16\u754c'
        ],
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
    const clusters = [
      {'name': 'Cluster A', 'summary': 'Summary A'},
      {'name': 'Cluster B', 'summary': 'Summary B'},
    ];

    test('names the platform the outline is for', () {
      final result =
          builder.buildOutlinePrompt(clusters, platform: _xiaohongshu);
      expect(result, contains('for a 小红书 post.'));
    });

    test('without a platform, asks for a plain post and states no rules', () {
      final result = builder.buildOutlinePrompt(clusters);
      expect(result, contains('for a post.'));
      expect(result, isNot(contains('Target platform')));
      expect(result, isNot(contains('Hard limits')));
    });

    test('carries the platform writing brief and its limits', () {
      final result =
          builder.buildOutlinePrompt(clusters, platform: _xiaohongshu);
      expect(result, contains('Target platform: 小红书'));
      // One brief line per item, as the server wrote them.
      expect(result, contains('- 像跟朋友讲这周干了什么。'));
      expect(result, contains('- 末尾放 3 到 5 个 #话题。'));
      expect(result, contains(_xhsLimits));
    });

    test('a platform without a brief still gets its limits', () {
      final result = builder.buildOutlinePrompt(clusters, platform: _zhihu);
      expect(result, contains('Target platform: 知乎'));
      expect(result, isNot(contains('How to write for it')));
      expect(
        result,
        contains('Hard limits: a title of at most 100 characters; '
            'a body of at most 50000 characters; at most 10 tags.'),
      );
    });

    test('does not forbid links where the platform allows them', () {
      final result = builder.buildOutlinePrompt(clusters, platform: _zhihu);
      expect(result, isNot(contains('no links')));
    });

    test('includes cluster name and summary for each cluster', () {
      final result = builder.buildOutlinePrompt(clusters);
      expect(result, contains('Cluster A: Summary A'));
      expect(result, contains('Cluster B: Summary B'));
    });

    test('includes JSON output schema with title and sections', () {
      final result = builder.buildOutlinePrompt(clusters);
      expect(result, contains('"title"'));
      expect(result, contains('"sections"'));
      expect(result, contains('"heading"'));
      expect(result, contains('"points"'));
      expect(result, contains('"source_cluster"'));
    });

    test('handles empty cluster list', () {
      final result = builder.buildOutlinePrompt([]);
      expect(result, contains('for a post.'));
    });

    test('injects the user topic into the prompt', () {
      final result = builder.buildOutlinePrompt(
        clusters,
        topic: 'My Special Topic',
      );
      expect(result, contains('User topic: My Special Topic'));
    });

    test('omits the topic line when topic is empty', () {
      final result = builder.buildOutlinePrompt(clusters, topic: '');
      expect(result, isNot(contains('User topic:')));
    });

    test('injects the template prompt fragment when provided', () {
      final result = builder.buildOutlinePrompt(
        clusters,
        template: _templateWithMarker(),
      );
      expect(result, contains('TEMPLATE_FRAGMENT_MARKER'));
    });
  });

  // ---------------------------------------------------------------------------
  // buildExpandPrompt
  // ---------------------------------------------------------------------------

  group('buildExpandPrompt', () {
    const outline = {'title': 'My Awesome Post', 'sections': []};

    test('includes outline title', () {
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
      final result = builder.buildExpandPrompt(outline, []);
      expect(result.toLowerCase(), contains('engaging'));
    });

    test('states the layout the draft is later split by', () {
      final result = builder.buildExpandPrompt(outline, ['note']);
      // PlatformDraft.parse relies on each of these.
      expect(result, contains('title on the first line'));
      expect(result, contains('"# Title"'));
      expect(result, contains('one last line holding only the hashtags'));
      expect(result, contains('Output only the post'));
    });

    test('carries the platform writing brief and its limits', () {
      final result =
          builder.buildExpandPrompt(outline, ['note'], platform: _xiaohongshu);
      expect(result, contains('Target platform: 小红书'));
      expect(result, contains('- 像跟朋友讲这周干了什么。'));
      expect(result, contains(_xhsLimits));
    });

    test('without a platform, states no platform rules', () {
      final result = builder.buildExpandPrompt(outline, ['note']);
      expect(result, isNot(contains('Target platform')));
      expect(result, isNot(contains('Hard limits')));
    });

    test('injects the user topic into the prompt', () {
      final result = builder.buildExpandPrompt(
        outline,
        ['note'],
        topic: 'Grow Tomatoes',
      );
      expect(result, contains('User topic: Grow Tomatoes'));
    });

    test('omits the topic line when topic is empty', () {
      final result = builder.buildExpandPrompt(
        outline,
        ['note'],
        topic: '',
      );
      expect(result, isNot(contains('User topic:')));
    });

    test('injects the template prompt fragment when provided', () {
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
    test('names the platform', () {
      final result = builder.buildStyleAdaptPrompt('content', platform: _zhihu);
      expect(result, contains('for 知乎.'));
    });

    test('includes the full content', () {
      const content = 'This is the original content to adapt.';
      final result = builder.buildStyleAdaptPrompt(content);
      expect(result, contains(content));
    });

    test('mentions tone, format, and style', () {
      final result = builder.buildStyleAdaptPrompt('content');
      expect(result.toLowerCase(), contains('tone'));
      expect(result.toLowerCase(), contains('format'));
      expect(result.toLowerCase(), contains('style'));
    });

    test('asks for the same layout as a new draft', () {
      final result = builder.buildStyleAdaptPrompt('content');
      expect(result, contains('title on the first line'));
      expect(result, contains('Output only the post'));
    });

    test('carries the platform writing brief and its limits', () {
      final result =
          builder.buildStyleAdaptPrompt('content', platform: _xiaohongshu);
      expect(result, contains('- 像跟朋友讲这周干了什么。'));
      expect(result, contains(_xhsLimits));
    });

    test('handles empty content string', () {
      final result = builder.buildStyleAdaptPrompt('', platform: _xiaohongshu);
      expect(result, contains('小红书'));
    });

    test('injects the template prompt fragment when provided', () {
      final result = builder.buildStyleAdaptPrompt(
        'content',
        template: _templateWithMarker(),
      );
      expect(result, contains('TEMPLATE_FRAGMENT_MARKER'));
      expect(result, contains('template specification'));
    });

    test('omits the template fragment when no template is given', () {
      final result = builder.buildStyleAdaptPrompt('content');
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

    test('has the refinement keep the layout the draft is split by', () {
      final result = builder.buildRefineSystemPrompt(null);
      expect(result, contains('title heading on the first line'));
      expect(result, contains('hashtag line last'));
      // Chatter around the post would be published along with it.
      expect(result, contains('output the post only'));
    });

    test('carries the platform rules so a refinement cannot break them', () {
      final result = builder.buildRefineSystemPrompt(
        null,
        platform: _xiaohongshu,
      );
      expect(result, contains('Target platform: 小红书'));
      expect(result, contains(_xhsLimits));
    });

    test('without a platform, states no platform rules', () {
      final result = builder.buildRefineSystemPrompt(null);
      expect(result, isNot(contains('Target platform')));
    });

    test('injects the template prompt fragment when provided', () {
      final result = builder.buildRefineSystemPrompt(_templateWithMarker());
      expect(result, contains('TEMPLATE_FRAGMENT_MARKER'));
    });

    test('omits the template section when no template is given', () {
      final result = builder.buildRefineSystemPrompt(null);
      expect(result, isNot(contains('TEMPLATE_FRAGMENT_MARKER')));
      expect(result, isNot(contains('Template specification')));
    });
  });
}
