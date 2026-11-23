import '../../publish/domain/publish_rules.dart';
import '../domain/post_template.dart';

/// Separator inserted between individual notes inside compose prompts.
///
/// A bare newline is ambiguous because a note may span multiple lines.
/// Pipelines that join notes into one string (e.g. for length truncation)
/// split back on this exact marker so per-note indices stay stable and
/// cluster `note_indices` keep referring to actual notes.
const String kNoteSeparator = '@@NOTE_SPLIT@@';

/// The layout every draft is written in, so `PlatformDraft.parse` can split
/// it into a title, a body and tags without guessing.
const String _layout = 'Output only the post, in this layout: the title on '
    'the first line as a markdown heading ("# Title"); then the body; then, '
    'if hashtags suit the platform, one last line holding only the hashtags. '
    'Do not label the parts and do not add remarks before or after.';

/// Client-side prompt builder for the AI compose pipeline.
///
/// All prompts are constructed on the client (never on the server). Prompts
/// are **template-aware** — when a [PostTemplate] is provided, its
/// `systemPrompt`, `structureHint`, and `toneHint` are injected to guide
/// format, tone, and structure — and **platform-aware**: when a
/// [PlatformGuide] is provided, the platform's writing brief and limits go
/// into every prompt that shapes the text, so a draft written for 小红书 is
/// conversational and link-free from the first version rather than after a
/// separate "adapt style" pass.
class PromptBuilder {
  /// Stage 1: Cluster notes by topic.
  String buildClusterPrompt(
    List<String> noteContents,
    String topic, {
    PostTemplate? template,
  }) {
    final tpl = template?.promptFragment;
    return '''You are a content organizer. Group the following notes by theme for a piece about "$topic".
${tpl != null ? '\nTarget format guidance:\n$tpl\n' : ''}
Notes (each labeled [index]; notes are separated by "$kNoteSeparator" markers):
${noteContents.asMap().entries.map((e) => '[${e.key}] ${e.value}').join('\n$kNoteSeparator\n')}

Output JSON:
{
  "clusters": [
    {
      "name": "Cluster name",
      "theme": "Core theme",
      "note_indices": [0, 2, 5],
      "summary": "Brief summary"
    }
  ]
}''';
  }

  /// Stage 2: Generate outline from clusters.
  String buildOutlinePrompt(
    List<Map<String, dynamic>> clusters, {
    String? topic,
    PostTemplate? template,
    PlatformGuide? platform,
  }) {
    final tpl = template?.promptFragment;
    final topicBlock =
        (topic != null && topic.isNotEmpty) ? '\nUser topic: $topic\n' : '';
    return '''Based on these note clusters, create a detailed outline for ${_target(platform)}.
${tpl != null ? '\nFollow this template:\n$tpl\n' : ''}${_platformBlock(platform)}$topicBlock
Clusters:
${clusters.map((c) => '- ${c['name']}: ${c['summary']}').join('\n')}

Output JSON:
{
  "title": "Suggested title",
  "sections": [
    {
      "heading": "Section heading",
      "points": ["Point 1", "Point 2"],
      "source_cluster": 0
    }
  ]
}''';
  }

  /// Stage 3: Expand outline into full content.
  String buildExpandPrompt(
    Map<String, dynamic> outline,
    List<String> sourceNotes, {
    String? topic,
    PostTemplate? template,
    PlatformGuide? platform,
  }) {
    final sections = (outline['sections'] as List?) ?? [];
    final tpl = template?.promptFragment;
    final topicBlock =
        (topic != null && topic.isNotEmpty) ? '\nUser topic: $topic\n' : '';
    return '''Write a detailed, engaging post based on this outline.
${tpl != null ? '\nYou must follow this template specification:\n$tpl\n' : ''}${_platformBlock(platform)}$topicBlock
Title: ${outline['title']}
Sections:
${sections.asMap().entries.map((e) {
      final s = e.value as Map<String, dynamic>;
      return '${e.key + 1}. ${s['heading']}\n   Points: ${(s['points'] as List?)?.join(', ')}';
    }).join('\n')}

Source material:
${sourceNotes.join('\n')}

$_layout
Write the full content now.''';
  }

  /// Stage 4: Adapt an existing draft for a specific platform.
  String buildStyleAdaptPrompt(
    String content, {
    PostTemplate? template,
    PlatformGuide? platform,
  }) {
    final tpl = template?.promptFragment;
    final target = platform?.name ?? 'the target platform';
    return '''Adapt the following content for $target. Adjust tone, format, and style to match the platform's conventions.
${tpl != null ? '\nKeep the following template specification (structure, tone, and format rules):\n$tpl\n' : ''}${_platformBlock(platform)}
Content:
$content

$_layout''';
  }

  // ── Chat-based refinement ─────────────────────────

  /// Build the system prompt for the refinement chat.
  ///
  /// The system prompt establishes the AI as a post editor that receives
  /// instructions and returns the FULL updated post (not a diff). The
  /// template's format rules are included so refinements stay on-template,
  /// and the platform's rules so a refinement cannot break what the draft
  /// already satisfied.
  String buildRefineSystemPrompt(
    PostTemplate? template, {
    PlatformGuide? platform,
  }) {
    final tpl = template?.promptFragment;
    final rules = _platformBlock(platform).trim();
    return 'You are an expert post editor. The user will give you '
        'instructions to refine a draft post. Apply the changes and output '
        'the FULL updated post (not a diff). Preserve the parts the user '
        'did not ask to change.'
        '${rules.isEmpty ? '' : '\n\n$rules'}'
        '\n\nKeep the post\'s layout — the title heading on the first line '
        'and, if there is one, the hashtag line last — and output the post '
        'only, with no remarks before or after.'
        '${tpl != null ? '\n\nTemplate specification:\n$tpl' : ''}';
  }

  // ── Template extraction ───────────────────────────

  /// Prompt for the AI agent to analyze a sample post and create a reusable
  /// template from its structure, tone, and format conventions.
  String buildExtractTemplatePrompt(String samplePost) {
    return '''Analyze the following post and create a reusable template from it.

Sample post:
$samplePost

Identify:
1. The overall structure (section order, heading style).
2. The tone and voice.
3. Formatting conventions (emoji, bullet points, hashtags, length).
4. Any platform-specific patterns.

Output JSON:
{
  "name": "A short descriptive name for this template",
  "description": "One-sentence description",
  "systemPrompt": "Detailed LLM instructions that capture the style, structure, tone, and format rules of this post type. Write as imperative instructions.",
  "structureHint": "e.g. 标题 → 钩子 → 正文 → CTA → 标签",
  "toneHint": "e.g. 轻松活泼, 第一人称"
}''';
  }

  // ── Utility ────────────────────────────────────────

  /// What the post is for, as a noun phrase.
  static String _target(PlatformGuide? platform) =>
      platform == null ? 'a post' : 'a ${platform.name} post';

  /// The platform's rules for the model: the writing brief the server keeps
  /// for each platform, then its limits as plain numbers — the brief states
  /// them in prose, and a limit is easier to keep when it is spelled out.
  static String _platformBlock(PlatformGuide? platform) {
    if (platform == null) return '';
    final limits = [
      'a title of at most ${platform.titleMax} characters',
      'a body of at most ${platform.contentMax} characters',
      if (platform.maxTags > 0) 'at most ${platform.maxTags} tags',
      if (!platform.linksAllowed) 'no links',
    ];
    final brief = platform.guidance.isEmpty
        ? ''
        : 'How to write for it:\n'
            '${platform.guidance.map((line) => '- $line').join('\n')}\n';
    return '\nTarget platform: ${platform.name}\n$brief'
        'Hard limits: ${limits.join('; ')}.\n';
  }

  /// Truncate [text] to [maxChars], appending a truncation marker if needed.
  static String truncateToLimit(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    const truncationSuffix = '... (truncated)';
    final cutOff = maxChars - truncationSuffix.length;
    if (cutOff <= 0) return truncationSuffix;
    return '${text.substring(0, cutOff)}$truncationSuffix';
  }
}
