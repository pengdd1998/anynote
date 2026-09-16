import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/compose/data/ai_repository.dart';

/// Daily cap on automatic tag-suggestion LLM calls (cost guard; the manual
/// AI-tag action stays unlimited).
const int _kMaxAutoTagsPerDay = 5;

/// Capture-time AI auto-tagging.
///
/// Asks the user's own LLM (client-direct, same contract as the manual
/// AI-tag sheet) for 3-5 short tags, with a daily quota stored in
/// SharedPreferences. Never throws: failures surface as an empty list.
class AutoTagger {
  final AIRepository _aiRepo;

  AutoTagger(this._aiRepo);

  /// Suggest tags for [content]. Returns an empty list when disabled by the
  /// daily quota, when content is too short, or on any failure.
  Future<List<String>> suggestTags(String content) async {
    final trimmed = content.trim();
    // Skip very short notes — not enough signal for meaningful tags.
    if (trimmed.length < 12) return const [];
    if (!await _consumeDailyQuota()) return const [];

    try {
      final response = await _aiRepo.chat([
        const ChatMessage(
          role: 'system',
          content: 'You are a tagging assistant for a note-taking app. '
              'Analyze the text and suggest 3 to 5 relevant tags. '
              'Tags should be short (1-3 words), lowercase, and concise. '
              'Respond with ONLY a JSON array of strings, no other text. '
              'Example: ["productivity", "meeting-notes", "project-alpha"]',
        ),
        ChatMessage(
          role: 'user',
          content: 'Suggest tags for this note:\n\n$trimmed',
        ),
      ]);
      return parseTagArray(response);
    } catch (e) {
      debugPrint('[AutoTagger] suggestion failed: $e');
      return const [];
    }
  }

  /// True when under the daily cap; increments the counter otherwise.
  Future<bool> _consumeDailyQuota() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final key = 'auto_tag_quota_$today';
      final used = prefs.getInt(key) ?? 0;
      if (used >= _kMaxAutoTagsPerDay) return false;
      await prefs.setInt(key, used + 1);
      return true;
    } catch (_) {
      // Quota tracking is best-effort; never block tagging on it.
      return true;
    }
  }

  /// Parses `["tag1", "tag2"]` out of an LLM reply that may carry prose or
  /// code fences around the array.
  static List<String> parseTagArray(String response) {
    final cleaned = response.trim();
    final start = cleaned.indexOf('[');
    final end = cleaned.lastIndexOf(']');
    if (start == -1 || end == -1 || end <= start) return const [];
    try {
      final decoded = jsonDecode(cleaned.substring(start, end + 1));
      if (decoded is! List) return const [];
      return decoded
          .whereType<String>()
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty && t.length <= 32)
          .take(5)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

/// Provider for the auto-tagger.
final autoTaggerProvider = Provider<AutoTagger>((ref) {
  return AutoTagger(ref.read(aiRepositoryProvider));
});
