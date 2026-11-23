import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/features/publish/presentation/widgets/publish_from_editor_sheet.dart';
import 'package:anynote/main.dart' show apiClientProvider;

import '../../../../helpers/test_app_helper.dart';

/// Answers the platform endpoints from memory and records what the
/// pre-publish check was asked.
class _SheetApiClient extends ApiClient {
  _SheetApiClient() : super(baseUrl: 'http://localhost:8080');

  List<Map<String, dynamic>> connected = [
    {'platform': 'xiaohongshu', 'display_name': '小红书', 'connected': true},
    {'platform': 'zhihu', 'display_name': '知乎', 'connected': true},
  ];
  final validationRequests = <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> listPlatforms() async => connected;

  @override
  Future<List<Map<String, dynamic>>> publishPlatforms() async => const [];

  @override
  Future<Map<String, dynamic>> validatePublish(
    Map<String, dynamic> req,
  ) async {
    validationRequests.add(req);
    return const {'valid': true};
  }
}

/// Opens [sheet] the way the compose editor does: from a button, as a modal
/// bottom sheet.
class _Host extends StatelessWidget {
  const _Host({required this.sheet});

  final Widget sheet;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TextButton(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => sheet,
        ),
        child: const Text('open'),
      ),
    );
  }
}

void main() {
  late _SheetApiClient api;

  setUp(() => api = _SheetApiClient());

  /// Opens the sheet and lets the bottom sheet animate in, the platform
  /// list load, and the pre-publish check's debounce elapse.
  Future<void> openSheet(
    WidgetTester tester,
    PublishFromEditorSheet sheet,
  ) async {
    final handle = await pumpScreen(
      tester,
      _Host(sheet: sheet),
      overrides: [
        ...defaultProviderOverrides(),
        apiClientProvider.overrideWithValue(api),
      ],
    );
    addTearDown(handle.dispose);

    await tester.tap(find.text('open'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// The card that publishes under [platformId], the way the server names it.
  Finder platformCard(String platformId) =>
      find.widgetWithText(ListTile, platformId);

  testWidgets('opens on the platform the draft was written for',
      (tester) async {
    await openSheet(
      tester,
      const PublishFromEditorSheet(
        title: '周末去了趟杭州',
        content: '西湖边走了走。',
        initialPlatform: 'xiaohongshu',
      ),
    );

    expect(
      find.descendant(
        of: platformCard('xiaohongshu'),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
    // And only that one.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('the draft fills the title, the body and the tags',
      (tester) async {
    await openSheet(
      tester,
      const PublishFromEditorSheet(
        title: '周末去了趟杭州',
        content: '西湖边走了走。',
        initialTags: ['周末去哪儿', '杭州'],
        initialPlatform: 'xiaohongshu',
      ),
    );

    expect(find.text('周末去了趟杭州'), findsOneWidget);
    expect(find.text('西湖边走了走。'), findsOneWidget);
    expect(find.text('周末去哪儿, 杭州'), findsOneWidget);
  });

  testWidgets('checks the draft against that platform\'s rules as it opens',
      (tester) async {
    await openSheet(
      tester,
      const PublishFromEditorSheet(
        title: '周末去了趟杭州',
        content: '西湖边走了走。',
        initialTags: ['杭州'],
        initialPlatform: 'xiaohongshu',
      ),
    );

    // Nobody typed anything: the draft arrived complete, so the sheet says
    // right away what the rules think of it.
    expect(api.validationRequests, [
      {
        'platform': 'xiaohongshu',
        'title': '周末去了趟杭州',
        'content': '西湖边走了走。',
        'tags': ['杭州'],
      },
    ]);
  });

  testWidgets('a platform that is not connected leaves nothing selected',
      (tester) async {
    api.connected = [
      {'platform': 'zhihu', 'display_name': '知乎', 'connected': true},
    ];

    await openSheet(
      tester,
      const PublishFromEditorSheet(
        title: '标题',
        content: '正文',
        initialPlatform: 'xiaohongshu',
      ),
    );

    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(api.validationRequests, isEmpty);
  });

  testWidgets('without a platform to preselect, nothing is selected',
      (tester) async {
    await openSheet(
      tester,
      const PublishFromEditorSheet(title: '标题', content: '正文'),
    );

    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(api.validationRequests, isEmpty);
  });
}
