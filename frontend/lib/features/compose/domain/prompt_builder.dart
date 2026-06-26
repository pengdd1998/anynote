import '../domain/post_template.dart';

/// Client-side prompt builder for the AI compose pipeline.
///
/// All prompts are constructed on the client (never on the server). Prompts
/// are **template-aware** — when a [PostTemplate] is provided, its
/// `systemPrompt`, `structureHint`, and `toneHint` are injected to guide
/// format, tone, and structure.
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
Notes:
${noteContents.asMap().entries.map((e) => '[${e.key}] ${e.value}').join('\n')}

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
    List<Map<String, dynamic>> clusters,
    String platform, {
    PostTemplate? template,
  }) {
    final tpl = template?.promptFragment;
    return '''Based on these note clusters, create a detailed outline for a $platform post.
${tpl != null ? '\nFollow this template:\n$tpl\n' : ''}
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
    PostTemplate? template,
  }) {
    final sections = (outline['sections'] as List?) ?? [];
    final tpl = template?.promptFragment;
    return '''Write a detailed, engaging post based on this outline.
${tpl != null ? '\nYou must follow this template specification:\n$tpl\n' : ''}
Title: ${outline['title']}
Sections:
${sections.asMap().entries.map((e) {
      final s = e.value as Map<String, dynamic>;
      return '${e.key + 1}. ${s['heading']}\n   Points: ${(s['points'] as List?)?.join(', ')}';
    }).join('\n')}

Source material:
${sourceNotes.join('\n')}

Write the full content now.''';
  }

  /// Stage 4: Adapt style for a specific platform (legacy — prefer templates).
  String buildStyleAdaptPrompt(String content, String platform) {
    return '''Adapt the following content for $platform. Adjust tone, format, and style to match platform conventions.

Content:
$content

Output the adapted content directly.''';
  }

  // ── Chat-based refinement ─────────────────────────

  /// Build the system prompt for the refinement chat.
  ///
  /// The system prompt establishes the AI as a post editor that receives
  /// instructions and returns the FULL updated post (not a diff). The
  /// template's format rules are included so refinements stay on-template.
  String buildRefineSystemPrompt(PostTemplate? template) {
    final tpl = template?.promptFragment;
    return 'You are an expert post editor. The user will give you '
        'instructions to refine a draft post. Apply the changes and output '
        'the FULL updated post (not a diff). Preserve the parts the user '
        'did not ask to change.${tpl != null ? '\n\nTemplate specification:\n$tpl' : ''}';
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

  /// Truncate [text] to [maxChars], appending a truncation marker if needed.
  static String truncateToLimit(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    const truncationSuffix = '... (truncated)';
    final cutOff = maxChars - truncationSuffix.length;
    if (cutOff <= 0) return truncationSuffix;
    return '${text.substring(0, cutOff)}$truncationSuffix';
  }
}
