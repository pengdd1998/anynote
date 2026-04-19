/// Data models for the markdown file import pipeline.
///
/// The import flow is:
///   1. [ImportedNote] - A parsed markdown file with extracted metadata.
///   2. [ImportProgress] - Streaming progress updates during parsing/import.
///   3. [ImportResult] - Final summary of what was imported, skipped, or failed.
library;

/// A single markdown file parsed into a structured note representation.
///
/// Frontmatter is extracted when present (YAML between --- delimiters).
/// Supported frontmatter fields:
///   - title: String (falls back to filename without .md extension)
///   - date: ISO 8601 date string (falls back to file modification time)
///   - tags: Comma-separated list or YAML flow sequence [tag1, tag2]
class ImportedNote {
  /// The note title extracted from frontmatter or filename.
  final String title;

  /// The markdown body (everything after the frontmatter delimiter).
  final String body;

  /// Tags extracted from frontmatter.
  final List<String> tags;

  /// Creation date from frontmatter or file metadata.
  final DateTime createdAt;

  /// Absolute path to the source file on disk.
  final String sourcePath;

  const ImportedNote({
    required this.title,
    required this.body,
    required this.tags,
    required this.createdAt,
    required this.sourcePath,
  });
}

/// Status of a single import step.
enum ImportStatus {
  /// Currently parsing markdown files.
  parsing,

  /// Currently encrypting and writing to the database.
  importing,

  /// All operations completed.
  done,

  /// A recoverable or fatal error occurred.
  failed,
}

/// A single progress update emitted during directory parsing or note import.
///
/// Use a [Stream<ImportProgress>] to drive a progress UI (e.g. a linear
/// progress indicator with the current file name).
class ImportProgress {
  /// Zero-based index of the file currently being processed.
  final int current;

  /// Total number of files to process.
  final int total;

  /// Display name of the file currently being processed.
  final String currentFile;

  /// Which phase the import pipeline is in.
  final ImportStatus status;

  const ImportProgress({
    required this.current,
    required this.total,
    required this.currentFile,
    required this.status,
  });

  /// Normalized progress in the range [0.0, 1.0].
  double get progress => total > 0 ? current / total : 0.0;
}

/// Final result of an import batch operation.
class ImportResult {
  /// Number of notes successfully inserted into the database.
  final int importedCount;

  /// Number of notes skipped (e.g. empty files, unreadable encoding).
  final int skippedCount;

  /// Per-file error descriptions for notes that failed to import.
  final List<ImportError> errors;

  const ImportResult({
    required this.importedCount,
    required this.skippedCount,
    this.errors = const [],
  });

  /// Whether any errors occurred during import.
  bool get hasErrors => errors.isNotEmpty;
}

/// Describes a single import failure for user feedback.
class ImportError {
  /// The source file path that failed.
  final String filePath;

  /// Human-readable error description.
  final String message;

  const ImportError({
    required this.filePath,
    required this.message,
  });
}
