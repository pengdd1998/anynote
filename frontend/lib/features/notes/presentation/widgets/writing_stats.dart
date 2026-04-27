/// Writing statistics computed from editor text content.
///
/// Handles both CJK and Latin text correctly:
/// - Word count: whitespace-split for Latin, character-count for CJK
/// - Reading time: 200 wpm for English, 400 chars/min for CJK
class WritingStats {
  /// Number of words (whitespace-delimited for Latin, character-count for CJK).
  final int wordCount;

  /// Total character count including spaces.
  final int charCount;

  /// Character count excluding spaces.
  final int charCountNoSpaces;

  /// Number of lines (newline-delimited).
  final int lineCount;

  /// Number of paragraphs (blocks of text separated by blank lines).
  final int paragraphCount;

  /// Estimated reading duration.
  final Duration estimatedReadingTime;

  /// Whether the text is predominantly CJK (Chinese/Japanese/Korean).
  final bool isCJK;

  const WritingStats({
    required this.wordCount,
    required this.charCount,
    required this.charCountNoSpaces,
    required this.lineCount,
    required this.paragraphCount,
    required this.estimatedReadingTime,
    required this.isCJK,
  });

  /// Zero stats for empty content.
  static const empty = WritingStats(
    wordCount: 0,
    charCount: 0,
    charCountNoSpaces: 0,
    lineCount: 0,
    paragraphCount: 0,
    estimatedReadingTime: Duration.zero,
    isCJK: false,
  );

  /// Compute writing statistics from plain text.
  ///
  /// Detects CJK content using Unicode ranges:
  /// - 0x4E00-0x9FFF: CJK Unified Ideographs
  /// - 0x3040-0x309F: Hiragana
  /// - 0x30A0-0x30FF: Katakana
  /// - 0xAC00-0xD7AF: Hangul Syllables
  static WritingStats fromText(String text) {
    if (text.isEmpty) return WritingStats.empty;

    final charCount = text.length;
    final charCountNoSpaces = text.replaceAll(RegExp(r'\s'), '').length;

    // Detect CJK content by counting CJK characters vs total non-space chars.
    int cjkCharCount = 0;
    for (int i = 0; i < text.length; i++) {
      final codeUnit = text.codeUnitAt(i);
      if (_isCJKCodePoint(codeUnit)) {
        cjkCharCount++;
      }
    }
    final isCJK =
        charCountNoSpaces > 0 && cjkCharCount / charCountNoSpaces > 0.3;

    // Word count: for CJK, each character is a "word". For Latin, split on
    // whitespace.
    final int wordCount;
    if (isCJK) {
      // CJK: count non-space characters plus any Latin words.
      // Split text into CJK chars and non-CJK segments.
      wordCount = _countCJKWords(text, cjkCharCount);
    } else {
      final trimmed = text.trim();
      wordCount = trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
    }

    // Line count: number of newline characters + 1 (if text is non-empty).
    final lineCount = '\n'.allMatches(text).length + 1;

    // Paragraph count: segments separated by one or more blank lines.
    final paragraphs =
        text.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty);
    final paragraphCount = paragraphs.isEmpty
        ? (text.trim().isNotEmpty ? 1 : 0)
        : paragraphs.length;

    // Reading time estimation.
    final Duration estimatedReadingTime;
    if (isCJK) {
      // CJK: ~400 characters per minute.
      final minutes = charCountNoSpaces / 400;
      estimatedReadingTime = Duration(
        milliseconds: (minutes * 60 * 1000).round(),
      );
    } else {
      // English: ~200 words per minute.
      final minutes = wordCount / 200;
      estimatedReadingTime = Duration(
        milliseconds: (minutes * 60 * 1000).round(),
      );
    }

    return WritingStats(
      wordCount: wordCount,
      charCount: charCount,
      charCountNoSpaces: charCountNoSpaces,
      lineCount: lineCount,
      paragraphCount: paragraphCount,
      estimatedReadingTime: estimatedReadingTime,
      isCJK: isCJK,
    );
  }

  /// Counts words for CJK-dominant text. Each CJK character counts as one
  /// word. Any embedded Latin text is split on whitespace.
  static int _countCJKWords(String text, int cjkCharCount) {
    // Simple approach: CJK chars count as words, plus any Latin words.
    int latinWordCount = 0;
    final latinSegments = <String>[];

    // Extract non-CJK segments.
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final codeUnit = text.codeUnitAt(i);
      if (_isCJKCodePoint(codeUnit)) {
        if (buffer.isNotEmpty) {
          latinSegments.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.writeCharCode(codeUnit);
      }
    }
    if (buffer.isNotEmpty) {
      latinSegments.add(buffer.toString());
    }

    for (final segment in latinSegments) {
      final trimmed = segment.trim();
      if (trimmed.isEmpty) continue;
      latinWordCount += trimmed.split(RegExp(r'\s+')).length;
    }

    return cjkCharCount + latinWordCount;
  }

  /// Whether the given UTF-16 code unit falls within a CJK Unicode range.
  static bool _isCJKCodePoint(int codeUnit) {
    return (codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) || // CJK Unified
        (codeUnit >= 0x3400 && codeUnit <= 0x4DBF) || // CJK Extension A
        (codeUnit >= 0x3040 && codeUnit <= 0x309F) || // Hiragana
        (codeUnit >= 0x30A0 && codeUnit <= 0x30FF) || // Katakana
        (codeUnit >= 0xAC00 && codeUnit <= 0xD7AF) || // Hangul
        (codeUnit >= 0xF900 && codeUnit <= 0xFAFF); // CJK Compat Ideographs
  }
}
