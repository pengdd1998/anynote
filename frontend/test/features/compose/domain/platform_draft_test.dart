import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/compose/domain/platform_draft.dart';

void main() {
  group('PlatformDraft.parse', () {
    test('splits a draft written in the layout the prompts ask for', () {
      final draft = PlatformDraft.parse(
        '# 周末去了趟杭州\n\n西湖边走了走，人不多。\n\n#周末去哪儿 #杭州',
      );
      expect(draft.title, '周末去了趟杭州');
      expect(draft.content, '西湖边走了走，人不多。');
      expect(draft.tags, ['周末去哪儿', '杭州']);
    });

    test('the title line is not repeated in the body', () {
      // Before the layout was defined, the whole draft went out as the
      // content, so a 20-character title ate into 小红书's 1000 and showed
      // up twice on the published note.
      final draft = PlatformDraft.parse('# 周末去了趟杭州\n西湖边走了走。');
      expect(draft.content, '西湖边走了走。');
      expect(draft.content, isNot(contains('周末去了趟杭州')));
    });

    test('the title is the first line even without a heading marker', () {
      final draft = PlatformDraft.parse('**周末去了趟杭州**\n西湖边走了走。');
      expect(draft.title, '周末去了趟杭州');
      expect(draft.content, '西湖边走了走。');
      expect(draft.tags, isEmpty);
    });

    test('a hashtag inside a sentence stays in the body', () {
      final draft = PlatformDraft.parse('# 标题\n今天去了 #咖啡店 喝咖啡。');
      expect(draft.content, '今天去了 #咖啡店 喝咖啡。');
      expect(draft.tags, isEmpty);
    });

    test('a heading that ends the body is not a tag line', () {
      final draft = PlatformDraft.parse('# 标题\n正文。\n\n## 小结');
      expect(draft.content, '正文。\n\n## 小结');
      expect(draft.tags, isEmpty);
    });

    test('a line with a hashtag and more besides stays in the body', () {
      final draft = PlatformDraft.parse('标题\n正文\n看 #旅行 频道');
      expect(draft.content, '正文\n看 #旅行 频道');
      expect(draft.tags, isEmpty);
    });

    test('a last line the user typed tags into is still understood', () {
      final draft = PlatformDraft.parse('标题\n正文\n#旅行，#美食; #咖啡、#散步');
      expect(draft.content, '正文');
      expect(draft.tags, ['旅行', '美食', '咖啡', '散步']);
    });

    test('keeps each tag once, in order of first appearance', () {
      final draft = PlatformDraft.parse('标题\n正文\n#旅行 #美食 #旅行');
      expect(draft.tags, ['旅行', '美食']);
    });

    test('reads tag lines up to the first line that is not one', () {
      final draft = PlatformDraft.parse('# 标题\n\n正文。\n\n#a\n#b\n\n\n');
      expect(draft.content, '正文。');
      expect(draft.tags, ['a', 'b']);
    });

    test('skips blank lines before the title', () {
      final draft = PlatformDraft.parse('\n\n# 标题\n正文。');
      expect(draft.title, '标题');
      expect(draft.content, '正文。');
    });

    test('a draft without tags keeps its last line in the body', () {
      final draft = PlatformDraft.parse('# 标题\n第一段。\n最后一段。');
      expect(draft.content, '第一段。\n最后一段。');
      expect(draft.tags, isEmpty);
    });

    test('a title on its own is a draft with an empty body', () {
      final draft = PlatformDraft.parse('# 只有标题');
      expect(draft.title, '只有标题');
      expect(draft.content, isEmpty);
      expect(draft.isEmpty, isFalse);
    });

    test('blank text is an empty draft', () {
      final draft = PlatformDraft.parse('  \n\n');
      expect(draft, isEmpty);
    });

    test(
        'keeps the body lines as written and drops only the blank ones '
        'around them', () {
      final draft = PlatformDraft.parse('# 标题\n\n  缩进的一段。\n\n\t下一行。  \n\n');
      expect(draft.content, '  缩进的一段。\n\n\t下一行。  ');
    });
  });
}
