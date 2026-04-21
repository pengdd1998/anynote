import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../main.dart';

/// Fetches the discovery feed from the API.
final discoverFeedProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, offset) async {
  final api = ref.watch(apiClientProvider);
  return api.discoverFeed(limit: 20, offset: offset);
});

/// Tracks reaction state for individual items in the feed.
/// Key format: "{shareId}:{reactionType}", value: true if active.
final reactionStateProvider =
    StateProvider.family<Map<String, bool>, String>((ref, id) {
  return {};
});
