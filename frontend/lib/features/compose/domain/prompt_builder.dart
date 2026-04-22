/// Client-side prompt builder for AI pipeline.
/// All prompts are constructed on the client (never on server).
class PromptBuilder {
  /// Stage 1: Cluster notes by topic.
  String buildClusterPrompt(List<String> noteContents, String topic) {
    return '''You are a content organizer. Group the following notes by theme for a piece about "$topic".

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
    String platform,
  ) {
    return '''Based on these note clusters, create a detailed outline for a $platform post.

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
    List<String> sourceNotes,
  ) {
    final sections = (outline['sections'] as List?) ?? [];
    return '''Write a detailed, engaging post based on this outline.

Title: ${outline['title']}
Sections:
${sections.asMap().entries.map((e) {
      final s = e.value as Map<String, dynamic>;
      return '${e.key + 1}. ${s['heading']}\n   Points: ${(s['points'] as List?)?.join(', ')}';
    }).join('\n')}

Source material:
${sourceNotes.join('\n')}

Write the full content in natural, engaging style.''';
  }

  /// Stage 4: Adapt style for specific platform.
  String buildStyleAdaptPrompt(String content, String platform) {
    return '''Adapt the following content for $platform. Adjust tone, format, and style to match platform conventions.

Content:
$content

Output the adapted content directly.''';
  }

  /// Truncate [text] to [maxChars], appending a truncation marker if needed.
  /// Returns the original text unchanged when it fits within the limit.
  static String truncateToLimit(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    const truncationSuffix = '... (truncated)';
    final cutOff = maxChars - truncationSuffix.length;
    if (cutOff <= 0) return truncationSuffix;
    return '${text.substring(0, cutOff)}$truncationSuffix';
  }
}
