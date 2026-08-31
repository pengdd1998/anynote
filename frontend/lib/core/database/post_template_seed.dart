/// Canonical seed data for the three built-in post templates.
///
/// Single source of truth for built-in post templates:
/// - `AppDatabase._seedBuiltInPostTemplates` inserts these rows into the
///   `post_templates` table on database creation / migration.
/// - The domain fallback `kBuiltInTemplates`
///   (`features/compose/domain/post_template.dart`) builds its offline
///   copies from these rows.
///
/// Keeping one list guarantees the seeded DB rows and the domain fallback
/// can never diverge again.
library;

/// Stable IDs for built-in templates (used by the migration seeder).
const kBuiltInTemplateGeneral = 'builtin-template-general';
const kBuiltInTemplateXhs = 'builtin-template-xhs';
const kBuiltInTemplateLongform = 'builtin-template-longform';

/// One built-in post template row (pure data; no domain dependencies).
class PostTemplateSeedData {
  final String id;
  final String name;
  final String description;

  /// LLM system-prompt fragment injected into compose prompts.
  final String systemPrompt;

  /// Human-readable structure overview (may be null).
  final String? structureHint;

  /// Tone descriptor (may be null).
  final String? toneHint;

  const PostTemplateSeedData({
    required this.id,
    required this.name,
    required this.description,
    required this.systemPrompt,
    this.structureHint,
    this.toneHint,
  });
}

/// The three built-in post templates.
const List<PostTemplateSeedData> kBuiltInPostTemplates = [
  PostTemplateSeedData(
    id: kBuiltInTemplateGeneral,
    name: '通用模板',
    description: '灵活通用的文章模板，适合任何主题和内容。',
    systemPrompt: 'Write a well-structured, engaging article. Use clear paragraphs with '
        'natural transitions. Adapt the length and depth to the source '
        'material. Keep the tone neutral and professional.',
    structureHint: '标题 → 引言 → 正文（分段）→ 总结',
    toneHint: '自然流畅, 专业中性',
  ),
  PostTemplateSeedData(
    id: kBuiltInTemplateXhs,
    name: '小红书种草文',
    description: '适合小红书的种草/分享文：吸睛标题、第一人称、emoji、要点、CTA、话题标签。',
    systemPrompt: 'Write a XHS(小红书) style post. Use a catchy title with emoji, '
        'first-person perspective, enthusiastic tone, bullet points, '
        'short paragraphs, CTA at the end, and 5-10 hashtag tags.',
    structureHint: '吸睛标题(emoji) → 钩子开头 → 要点正文(bullet) → CTA → #话题标签',
    toneHint: '轻松活泼, 热情, 第一人称',
  ),
  PostTemplateSeedData(
    id: kBuiltInTemplateLongform,
    name: '公众号/长文',
    description: '适合公众号、博客的长文：结构化标题、叙事流畅、1000字以上、专业深度。',
    systemPrompt: 'Write a long-form article for WeChat/blog. Use section headings (##), '
        'in-depth analysis with examples from source, professional tone, '
        '1000-2500 characters.',
    structureHint: '深度标题 → 引言(钩子) → 分章节正文(##) → 深度分析 → 总结升华',
    toneHint: '专业严谨, 有深度',
  ),
];
