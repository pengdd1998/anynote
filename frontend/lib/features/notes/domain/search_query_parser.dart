/// Parses a search string with structured operators into a [SearchQuery].
///
/// Supported operators:
/// - `tag:name` -- filter by tag (case-insensitive prefix match)
/// - `status:value` -- filter by note status
/// - `priority:value` -- filter by note priority
/// - `date:YYYY`, `date:YYYY-MM`, `date:YYYY-MM-DD` -- filter by date
/// - `date:>YYYY-MM-DD` -- notes created after date
/// - `date:<YYYY-MM-DD` -- notes created before date
/// - `collection:name` -- filter by collection (case-insensitive prefix match)
/// - `links:true` / `links:false` -- filter by link status
/// - `color:#RRGGBB` or `color:name` -- filter by note color
///
/// Remaining text (not part of any operator) becomes the FTS5 full-text query.
/// Multiple operators can be combined.
library;

/// Represents a parsed date filter with optional comparison direction.
class DateFilter {
  /// The parsed date value (start of day/month/year depending on granularity).
  final DateTime value;

  /// Whether this is a "greater than" filter (date:>...).
  final bool isAfter;

  /// Whether this is a "less than" filter (date:<...).
  final bool isBefore;

  /// The granularity: 'year', 'month', or 'day'.
  final String granularity;

  const DateFilter({
    required this.value,
    this.isAfter = false,
    this.isBefore = false,
    this.granularity = 'day',
  });

  /// Returns the effective start date for filtering.
  DateTime get startDate {
    if (isAfter) {
      return DateTime(value.year, value.month, value.day + 1);
    }
    return value;
  }

  /// Returns the effective end date for filtering.
  DateTime get endDate {
    if (isBefore) {
      return DateTime(value.year, value.month, value.day - 1, 23, 59, 59);
    }
    switch (granularity) {
      case 'year':
        return DateTime(value.year, 12, 31, 23, 59, 59);
      case 'month':
        return DateTime(value.year, value.month + 1, 0, 23, 59, 59);
      default:
        return DateTime(value.year, value.month, value.day, 23, 59, 59);
    }
  }
}

/// A structured search query parsed from user input.
class SearchQuery {
  /// Remaining text for FTS5 full-text matching.
  final String fullTextQuery;

  /// Tag name filters (case-insensitive prefix match against plain_name).
  final List<String> tagFilters;

  /// Status filter value (normalized to lowercase with hyphens).
  final String? statusFilter;

  /// Priority filter value (normalized to lowercase).
  final String? priorityFilter;

  /// Date range filter, or null if no date operator was specified.
  final DateFilter? dateFilter;

  /// Collection name filters (case-insensitive prefix match).
  final List<String> collectionFilters;

  /// Whether to filter notes that have at least one link (true),
  /// or notes that have no links / are orphaned (false).
  /// Null means no filter on link status.
  final bool? hasLinks;

  /// Color filter value. Can be a hex color like '#FF5722' or a named color
  /// like 'red'. Normalized to lowercase for matching.
  final String? colorFilter;

  const SearchQuery({
    this.fullTextQuery = '',
    this.tagFilters = const [],
    this.statusFilter,
    this.priorityFilter,
    this.dateFilter,
    this.collectionFilters = const [],
    this.hasLinks,
    this.colorFilter,
  });

  /// Whether any operator filter is active (beyond just full-text query).
  bool get hasOperatorFilters =>
      tagFilters.isNotEmpty ||
      statusFilter != null ||
      priorityFilter != null ||
      dateFilter != null ||
      collectionFilters.isNotEmpty ||
      hasLinks != null ||
      colorFilter != null;
}

/// Parses a raw search input string into a structured [SearchQuery].
///
/// Operators are `key:value` pairs where key is one of the recognized
/// operator names. Remaining text that is not part of any operator
/// becomes the full-text query for FTS5 matching.
SearchQuery parseSearchQuery(String input) {
  if (input.trim().isEmpty) {
    return const SearchQuery();
  }

  final tokens = _tokenize(input);
  final fullTextParts = <String>[];
  final tagFilters = <String>[];
  final collectionFilters = <String>[];
  String? statusFilter;
  String? priorityFilter;
  DateFilter? dateFilter;
  bool? hasLinks;
  String? colorFilter;

  for (final token in tokens) {
    final operator = _tryParseOperator(token);
    if (operator != null) {
      switch (operator.key) {
        case 'tag':
          tagFilters.add(operator.value);
          break;
        case 'status':
          statusFilter = _normalizeStatus(operator.value);
          break;
        case 'priority':
          priorityFilter = _normalizePriority(operator.value);
          break;
        case 'date':
          dateFilter = _parseDateFilter(operator.value);
          break;
        case 'collection':
          collectionFilters.add(operator.value);
          break;
        case 'links':
          hasLinks = _parseBool(operator.value);
          break;
        case 'color':
          colorFilter = _normalizeColor(operator.value);
          break;
      }
    } else {
      fullTextParts.add(token);
    }
  }

  return SearchQuery(
    fullTextQuery: fullTextParts.join(' ').trim(),
    tagFilters: tagFilters,
    statusFilter: statusFilter,
    priorityFilter: priorityFilter,
    dateFilter: dateFilter,
    collectionFilters: collectionFilters,
    hasLinks: hasLinks,
    colorFilter: colorFilter,
  );
}

/// Represents a parsed `key:value` operator.
class _Operator {
  final String key;
  final String value;
  const _Operator(this.key, this.value);
}

/// Tries to parse a token as a `key:value` operator.
/// Returns null if the token is not a recognized operator.
_Operator? _tryParseOperator(String token) {
  // Find the first colon that separates key from value.
  final colonIndex = token.indexOf(':');
  if (colonIndex <= 0 || colonIndex >= token.length - 1) {
    return null;
  }

  final key = token.substring(0, colonIndex).toLowerCase();
  final value = token.substring(colonIndex + 1);

  const validKeys = {
    'tag',
    'status',
    'priority',
    'date',
    'collection',
    'links',
    'color',
  };
  if (!validKeys.contains(key)) {
    return null;
  }

  return _Operator(key, value);
}

/// Tokenizes the input string, preserving `key:value` pairs as single tokens
/// and splitting remaining text on whitespace.
List<String> _tokenize(String input) {
  final result = <String>[];
  final buffer = StringBuffer();
  var i = 0;

  while (i < input.length) {
    final char = input[i];

    if (char == ' ' || char == '\t') {
      if (buffer.isNotEmpty) {
        result.add(buffer.toString());
        buffer.clear();
      }
      i++;
      continue;
    }

    // Check if this could be the start of a key:value operator.
    // We look ahead to find a colon before the next space.
    if (_isLetter(char)) {
      final colonPos = _findColonBeforeSpace(input, i);
      if (colonPos > i && colonPos < input.length - 1) {
        final potentialKey = input.substring(i, colonPos).toLowerCase();
        const validKeys = {
          'tag',
          'status',
          'priority',
          'date',
          'collection',
          'links',
          'color',
        };
        if (validKeys.contains(potentialKey)) {
          // Find the end of the value (next space or end of string).
          var valueEnd = colonPos + 1;
          while (valueEnd < input.length &&
              input[valueEnd] != ' ' &&
              input[valueEnd] != '\t') {
            valueEnd++;
          }
          result.add(input.substring(i, valueEnd));
          i = valueEnd;
          continue;
        }
      }
    }

    buffer.write(char);
    i++;
  }

  if (buffer.isNotEmpty) {
    result.add(buffer.toString());
  }

  return result;
}

/// Returns true if [char] is a letter (a-z, A-Z).
bool _isLetter(String char) {
  final code = char.codeUnitAt(0);
  return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
}

/// Finds the index of the next colon in [input] starting from [start],
/// stopping if a space is encountered first. Returns -1 if not found.
int _findColonBeforeSpace(String input, int start) {
  for (var i = start; i < input.length; i++) {
    final char = input[i];
    if (char == ' ' || char == '\t') return -1;
    if (char == ':') return i;
  }
  return -1;
}

/// Normalizes a status value to the canonical form used in the database.
/// Accepts variations like "todo", "in-progress", "in_progress", "done", etc.
String? _normalizeStatus(String value) {
  final lower = value.toLowerCase().replaceAll('_', '-').replaceAll(' ', '-');
  switch (lower) {
    case 'todo':
      return 'Todo';
    case 'in-progress':
    case 'inprogress':
      return 'In Progress';
    case 'done':
      return 'Done';
    case 'blocked':
      return 'Blocked';
    case 'cancelled':
    case 'canceled':
      return 'Cancelled';
    default:
      // Return the original value capitalized as-is for display matching.
      // The query will do case-insensitive comparison.
      return value;
  }
}

/// Normalizes a priority value to the canonical form.
String? _normalizePriority(String value) {
  final lower = value.toLowerCase();
  switch (lower) {
    case 'high':
    case 'h':
      return 'High';
    case 'medium':
    case 'med':
    case 'm':
      return 'Medium';
    case 'low':
    case 'l':
      return 'Low';
    default:
      return value;
  }
}

/// Parses a date value string into a [DateFilter].
/// Supports: YYYY, YYYY-MM, YYYY-MM-DD, >YYYY-MM-DD, <YYYY-MM-DD.
DateFilter? _parseDateFilter(String value) {
  if (value.isEmpty) return null;

  bool isAfter = false;
  bool isBefore = false;
  String dateStr = value;

  if (dateStr.startsWith('>')) {
    isAfter = true;
    dateStr = dateStr.substring(1);
  } else if (dateStr.startsWith('<')) {
    isBefore = true;
    dateStr = dateStr.substring(1);
  }

  // Try parsing YYYY-MM-DD.
  final fullDate = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$');
  final match = fullDate.firstMatch(dateStr);
  if (match != null) {
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateFilter(
      value: DateTime(year, month, day),
      isAfter: isAfter,
      isBefore: isBefore,
      granularity: 'day',
    );
  }

  // Try parsing YYYY-MM.
  final monthDate = RegExp(r'^(\d{4})-(\d{1,2})$');
  final monthMatch = monthDate.firstMatch(dateStr);
  if (monthMatch != null) {
    final year = int.parse(monthMatch.group(1)!);
    final month = int.parse(monthMatch.group(2)!);
    if (month < 1 || month > 12) return null;
    return DateFilter(
      value: DateTime(year, month),
      isAfter: isAfter,
      isBefore: isBefore,
      granularity: 'month',
    );
  }

  // Try parsing YYYY.
  final yearDate = RegExp(r'^(\d{4})$');
  final yearMatch = yearDate.firstMatch(dateStr);
  if (yearMatch != null) {
    final year = int.parse(yearMatch.group(1)!);
    return DateFilter(
      value: DateTime(year),
      isAfter: isAfter,
      isBefore: isBefore,
      granularity: 'year',
    );
  }

  return null;
}

/// Parses a boolean value from a string.
bool? _parseBool(String value) {
  switch (value.toLowerCase()) {
    case 'true':
    case 'yes':
    case '1':
      return true;
    case 'false':
    case 'no':
    case '0':
      return false;
    default:
      return null;
  }
}

/// Named color map for common color names to hex values.
const _namedColors = <String, String>{
  'red': '#F44336',
  'pink': '#E91E63',
  'purple': '#9C27B0',
  'deep-purple': '#673AB7',
  'indigo': '#3F51B5',
  'blue': '#2196F3',
  'light-blue': '#03A9F4',
  'cyan': '#00BCD4',
  'teal': '#009688',
  'green': '#4CAF50',
  'light-green': '#8BC34A',
  'lime': '#CDDC39',
  'yellow': '#FFEB3B',
  'amber': '#FFC107',
  'orange': '#FF9800',
  'deep-orange': '#FF5722',
  'brown': '#795548',
  'grey': '#9E9E9E',
  'blue-grey': '#607D8B',
};

/// Normalizes a color value to a hex color string.
/// Accepts hex values like '#FF5722' or named colors like 'red'.
/// Returns the hex color (uppercase with # prefix) or null if invalid.
String? _normalizeColor(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;

  // Check if it's a named color.
  final named = _namedColors[trimmed.toLowerCase()];
  if (named != null) return named.toUpperCase();

  // Check if it's a hex color.
  final hexPattern = RegExp(r'^#?([0-9A-Fa-f]{6})$');
  final match = hexPattern.firstMatch(trimmed);
  if (match != null) {
    final hex = match.group(1)!.toUpperCase();
    return '#$hex';
  }

  return null;
}
