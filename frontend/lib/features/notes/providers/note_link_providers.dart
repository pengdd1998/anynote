import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../main.dart';
import '../data/note_link_repository.dart';
import '../domain/note_link.dart';

/// Provider for [NoteLinkRepository].
final noteLinkRepositoryProvider = Provider<NoteLinkRepository>((ref) {
  return NoteLinkRepository(ref.read(apiClientProvider));
});

/// Provider for backlinks of a specific note.
final backlinksProvider =
    FutureProvider.family<List<NoteLink>, String>((ref, noteId) {
  final repo = ref.read(noteLinkRepositoryProvider);
  return repo.getBacklinks(noteId);
});

/// Provider for outbound links of a specific note.
final outboundLinksProvider =
    FutureProvider.family<List<NoteLink>, String>((ref, noteId) {
  final repo = ref.read(noteLinkRepositoryProvider);
  return repo.getOutboundLinks(noteId);
});

/// Provider for the full note graph.
final noteGraphProvider = FutureProvider<Map<String, dynamic>>((ref) {
  final repo = ref.read(noteLinkRepositoryProvider);
  return repo.getGraph();
});
