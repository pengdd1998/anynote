import 'package:uuid/uuid.dart';

/// A reusable template for AI-generated posts.
///
/// Templates define the structure, tone, and format conventions that the AI
/// should follow when composing a post from notes. Built-in templates cover
/// common formats; users can create their own or extract them from sample
/// posts via the AI agent.
class PostTemplate {
  final String id;
  final String name;
  final String description;

  /// LLM system-prompt fragment — injected into the AI's context to guide
  /// format, tone, and structure.
  final String systemPrompt;

  /// Human-readable structure overview (e.g. "标题 → 钩子 → 正文 → CTA → 标签").
  final String? structureHint;

  /// Tone descriptor (e.g. "轻松活泼, 多用 emoji").
  final String? toneHint;

  /// Built-in templates are seeded by the migration and cannot be deleted.
  final bool isBuiltIn;

  final DateTime createdAt;

  const PostTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.systemPrompt,
    this.structureHint,
    this.toneHint,
    this.isBuiltIn = false,
    required this.createdAt,
  });

  factory PostTemplate.create({
    required String name,
    required String description,
    required String systemPrompt,
    String? structureHint,
    String? toneHint,
    bool isBuiltIn = false,
  }) {
    return PostTemplate(
      id: const Uuid().v4(),
      name: name,
      description: description,
      systemPrompt: systemPrompt,
      structureHint: structureHint,
      toneHint: toneHint,
      isBuiltIn: isBuiltIn,
      createdAt: DateTime.now(),
    );
  }

  PostTemplate copyWith({
    String? name,
    String? description,
    String? systemPrompt,
    String? structureHint,
    String? toneHint,
  }) {
    return PostTemplate(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      structureHint: structureHint ?? this.structureHint,
      toneHint: toneHint ?? this.toneHint,
      isBuiltIn: isBuiltIn,
      createdAt: createdAt,
    );
  }

  /// Compact prompt fragment injected into outline / expand / refine prompts.
  String get promptFragment {
    final parts = <String>[];
    if (systemPrompt.isNotEmpty) parts.add(systemPrompt);
    if (structureHint != null && structureHint!.isNotEmpty) {
      parts.add('Structure: $structureHint');
    }
    if (toneHint != null && toneHint!.isNotEmpty) {
      parts.add('Tone: $toneHint');
    }
    return parts.join('\n');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'systemPrompt': systemPrompt,
        'structureHint': structureHint,
        'toneHint': toneHint,
        'isBuiltIn': isBuiltIn,
      };
}

// ── Built-in templates (seeded by migration) ────────────────────────────

/// Stable IDs for built-in templates (used by the migration seeder).
const kBuiltInTemplateGeneral = 'builtin-template-general';
const kBuiltInTemplateXhs = 'builtin-template-xhs';
const kBuiltInTemplateLongform = 'builtin-template-longform';

/// The three built-in post templates, seeded into the DB on first creation.
final List<PostTemplate> kBuiltInTemplates = [
  PostTemplate(
    id: kBuiltInTemplateGeneral,
    name: '通用模板',
    description: '灵活通用的文章模板，适合任何主题和内容。',
    systemPrompt: 'Write a well-structured, engaging article. Use clear '
        'paragraphs with natural transitions. Adapt the length and depth '
        'to the source material. Keep the tone neutral and professional.',
    structureHint: '标题 → 引言 → 正文（分段）→ 总结',
    toneHint: '自然流畅, 专业中性',
    isBuiltIn: true,
    createdAt: DateTime(2026, 6, 26),
  ),
  PostTemplate(
    id: kBuiltInTemplateXhs,
    name: '小红书种草文',
    description: '适合小红书的种草/分享文：吸睛标题、第一人称、emoji、要点、CTA、话题标签。',
    systemPrompt: 'Write a 小红书(XHS) style post. Requirements:\n'
        '- Catchy title with emoji (under 20 chars).\n'
        '- First-person perspective, enthusiastic and personal.\n'
        '- Use emoji throughout to add personality.\n'
        '- Organize content with bullet points (using • or numbers).\n'
        '- Keep paragraphs short (1-3 sentences).\n'
        '- End with a clear call-to-action (asking for likes/saves/comments).\n'
        '- Append 5-10 relevant hashtag tags at the bottom (format: #tag).\n'
        '- Total length: 300-800 characters.',
    structureHint: '吸睛标题(emoji) → 钩子开头 → 要点正文(bullet) → CTA → #话题标签',
    toneHint: '轻松活泼, 热情, 第一人称, 多用emoji',
    isBuiltIn: true,
    createdAt: DateTime(2026, 6, 26),
  ),
  PostTemplate(
    id: kBuiltInTemplateLongform,
    name: '公众号/长文',
    description: '适合公众号、博客的长文：结构化标题、叙事流畅、1000字以上、专业深度。',
    systemPrompt: 'Write a long-form article suitable for a WeChat Official '
        'Account or blog. Requirements:\n'
        '- Compelling title that promises value.\n'
        '- Engaging introduction that hooks the reader.\n'
        '- Use section headings (##) to organize content.\n'
        '- Each section should have 2-4 paragraphs of in-depth analysis.\n'
        '- Include concrete examples, data points, or quotes from source material.\n'
        '- Maintain a professional yet accessible tone.\n'
        '- End with a thoughtful conclusion that ties everything together.\n'
        '- Total length: 1000-2500 characters.',
    structureHint: '深度标题 → 引言(钩子) → 分章节正文(## 标题) → 深度分析 → 总结升华',
    toneHint: '专业严谨, 有深度, 叙事流畅',
    isBuiltIn: true,
    createdAt: DateTime(2026, 6, 26),
  ),
];
