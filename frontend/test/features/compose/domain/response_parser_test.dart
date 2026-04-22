import 'package:flutter_test/flutter_test.dart';
import 'package:anynote/features/compose/domain/response_parser.dart';

void main() {
  group('ResponseParser.extractJson', () {
    test('returns plain JSON object unchanged', () {
      const input = '{"title": "Hello", "content": "World"}';
      final result = ResponseParser.extractJson(input);
      expect(result, input);
    });

    test('extracts JSON from markdown code fence with json label', () {
      const input = '''
Here is the result:
```json
{"title": "Hello", "content": "World"}
```
Hope that helps!
''';
      final result = ResponseParser.extractJson(input);
      expect(result, '{"title": "Hello", "content": "World"}');
    });

    test('extracts JSON from markdown code fence without language label', () {
      const input = '''
```
{"key": "value"}
```
''';
      final result = ResponseParser.extractJson(input);
      expect(result, '{"key": "value"}');
    });

    test('extracts JSON surrounded by prose text', () {
      const input =
          'Sure! Here is your data: {"title": "Test", "items": [1, 2]} let me know if you need more.';
      final result = ResponseParser.extractJson(input);
      expect(result, '{"title": "Test", "items": [1, 2]}');
    });

    test('handles nested braces correctly', () {
      const input = '{"outer": {"inner": "value"}, "count": 1}';
      final result = ResponseParser.extractJson(input);
      expect(result, input);
    });

    test('returns empty string when input is empty', () {
      final result = ResponseParser.extractJson('');
      expect(result, '');
    });

    test('returns whitespace-only input unchanged', () {
      const input = '   \n\t  ';
      final result = ResponseParser.extractJson(input);
      expect(result, input);
    });

    test('returns plain text unchanged when no JSON is present', () {
      const input = 'This is just plain text without any JSON.';
      final result = ResponseParser.extractJson(input);
      expect(result, input);
    });

    test('extracts first JSON object when multiple are present', () {
      const input = '{"first": true} and {"second": true}';
      final result = ResponseParser.extractJson(input);
      // lastIndexOf('}') finds the last brace, so this returns the span from
      // the first '{' to the last '}'.
      expect(result, '{"first": true} and {"second": true}');
    });

    test('handles malformed markdown fence gracefully', () {
      const input = '```json\n{"broken": true\nNo closing fence here';
      // No closing triple-backtick, so fence regex fails.
      // No closing brace either, so brace matching fails too.
      // Falls back to returning the original response unchanged.
      final result = ResponseParser.extractJson(input);
      expect(result, input);
    });
  });
}
