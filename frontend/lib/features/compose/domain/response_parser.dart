/// Parses AI responses that may contain JSON wrapped in markdown fences
/// or surrounded by extra text.
class ResponseParser {
  ResponseParser._();

  /// Extract a JSON object from an AI response that may contain
  /// markdown code fences or extra text around the JSON.
  ///
  /// Tries three strategies in order:
  /// 1. JSON block inside markdown code fences (```json ... ```).
  /// 2. Raw JSON object delimited by the outermost `{` and `}`.
  /// 3. Returns the original response unchanged as a fallback.
  static String extractJson(String response) {
    // Try to find JSON block in markdown code fences.
    final fenceMatch =
        RegExp(r'```(?:json)?\s*\n?([\s\S]*?)\n?```').firstMatch(response);
    if (fenceMatch != null) {
      return fenceMatch.group(1)!.trim();
    }

    // Try to find a raw JSON object.
    final braceStart = response.indexOf('{');
    final braceEnd = response.lastIndexOf('}');
    if (braceStart != -1 && braceEnd > braceStart) {
      return response.substring(braceStart, braceEnd + 1);
    }

    return response;
  }
}
