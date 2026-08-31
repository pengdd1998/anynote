import 'package:uuid/uuid.dart';

import '../../../core/database/post_template_seed.dart';

// Re-export the stable built-in template IDs so existing importers of this
// file keep resolving them from their historical location.
export '../../../core/database/post_template_seed.dart'
    show
        kBuiltInTemplateGeneral,
        kBuiltInTemplateXhs,
        kBuiltInTemplateLongform;

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

/// The three built-in post templates, seeded into the DB on first creation.
///
/// Built from the canonical seed data (`kBuiltInPostTemplates` in
/// `core/database/post_template_seed.dart`) so this fallback list and the
/// seeded DB rows always match. Used only when the database is unavailable.
final List<PostTemplate> kBuiltInTemplates = kBuiltInPostTemplates
    .map(
      (t) => PostTemplate(
        id: t.id,
        name: t.name,
        description: t.description,
        systemPrompt: t.systemPrompt,
        structureHint: t.structureHint,
        toneHint: t.toneHint,
        isBuiltIn: true,
        createdAt: DateTime(2026, 6, 26),
      ),
    )
    .toList();
