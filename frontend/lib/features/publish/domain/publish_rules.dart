/// One finding from the server's publish checks.
///
/// [blocking] findings come back from `POST /api/v1/publish` as a 400 and
/// stop the post; the others are advice the user may ignore.
class PublishProblem {
  const PublishProblem({
    required this.field,
    required this.blocking,
    required this.message,
  });

  /// What the finding is about: `title`, `content` or `tags`.
  final String field;
  final bool blocking;
  final String message;

  factory PublishProblem.fromJson(Map<String, dynamic> json) => PublishProblem(
        field: json['field'] as String? ?? '',
        blocking: json['severity'] == 'error',
        message: json['message'] as String? ?? '',
      );

  @override
  String toString() => '${blocking ? 'error' : 'warning'} on $field: $message';
}

/// Reads the `problems` arrays out of a publish response or error body.
///
/// The server attaches blocking problems to the `error` of a 400 and
/// advisory ones to an accepted response; both shapes are handled so the
/// caller never has to know which it has.
class PublishProblems {
  const PublishProblems({this.blocking = const [], this.advisory = const []});

  final List<PublishProblem> blocking;
  final List<PublishProblem> advisory;

  static const empty = PublishProblems();

  static List<PublishProblem> _list(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => PublishProblem.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// From a successful (202) publish response.
  static PublishProblems fromResponse(Map<String, dynamic>? body) =>
      PublishProblems(advisory: _list(body?['warnings']));

  /// From the body of a failed request, whatever the status.
  static PublishProblems fromErrorBody(dynamic body) {
    if (body is! Map) return empty;
    final error = body['error'];
    if (error is! Map) return empty;
    final all = _list(error['problems']);
    return PublishProblems(
      blocking: all.where((p) => p.blocking).toList(),
      advisory: all.where((p) => !p.blocking).toList(),
    );
  }

  /// From a `POST /api/v1/publish/validate` response, which lists both
  /// kinds in one array.
  static PublishProblems fromValidation(Map<String, dynamic>? body) {
    final all = _list(body?['problems']);
    return PublishProblems(
      blocking: all.where((p) => p.blocking).toList(),
      advisory: all.where((p) => !p.blocking).toList(),
    );
  }

  /// The server's own one-line summary of why the request was rejected.
  static String? rejectionMessage(dynamic body) {
    if (body is! Map) return null;
    final error = body['error'];
    if (error is! Map) return null;
    final message = error['message'];
    return message is String && message.isNotEmpty ? message : null;
  }
}

/// A platform's publishing rules as the server declares them
/// (`GET /api/v1/publish/platforms`): the limits an editor enforces while
/// the user types, and the writing brief the AI composition step follows.
class PlatformGuide {
  const PlatformGuide({
    required this.id,
    required this.name,
    required this.titleMax,
    required this.contentMax,
    required this.maxTags,
    required this.linksAllowed,
    this.guidance = const [],
  });

  final String id;
  final String name;
  final int titleMax;
  final int contentMax;
  final int maxTags;
  final bool linksAllowed;

  /// One sentence per item: audience and tone first, then structure, then
  /// what gets a post rejected.
  final List<String> guidance;

  factory PlatformGuide.fromJson(Map<String, dynamic> json) => PlatformGuide(
        id: json['id'] as String,
        name: json['name'] as String,
        titleMax: (json['title_max'] as num).toInt(),
        contentMax: (json['content_max'] as num).toInt(),
        maxTags: (json['max_tags'] as num).toInt(),
        linksAllowed: json['links_allowed'] as bool,
        guidance: (json['guidance'] as List? ?? const [])
            .whereType<String>()
            .toList(),
      );

  /// Number of characters in [text] as the server counts them: one per
  /// user-perceived character, so a Chinese character is 1, not 3.
  static int lengthOf(String text) => text.runes.length;
}

/// The platform rules to show when the server's cannot be fetched, so an
/// editor still knows the limits offline. Mirrors the limits in the server's
/// `internal/platform/spec`; the server stays the source of truth and
/// overrides these whenever it answers.
const fallbackPlatformGuides = <PlatformGuide>[
  PlatformGuide(
      id: 'xiaohongshu',
      name: '小红书',
      titleMax: 20,
      contentMax: 1000,
      maxTags: 10,
      linksAllowed: false),
  PlatformGuide(
      id: 'wechat',
      name: '微信公众号',
      titleMax: 64,
      contentMax: 20000,
      maxTags: 10,
      linksAllowed: true),
  PlatformGuide(
      id: 'zhihu',
      name: '知乎',
      titleMax: 100,
      contentMax: 50000,
      maxTags: 10,
      linksAllowed: true),
  PlatformGuide(
      id: 'medium',
      name: 'Medium',
      titleMax: 150,
      contentMax: 50000,
      maxTags: 5,
      linksAllowed: true),
  PlatformGuide(
      id: 'wordpress',
      name: 'WordPress',
      titleMax: 200,
      contentMax: 100000,
      maxTags: 30,
      linksAllowed: true),
  PlatformGuide(
      id: 'webhook',
      name: 'Webhook',
      titleMax: 500,
      contentMax: 10000000,
      maxTags: 50,
      linksAllowed: true),
];
