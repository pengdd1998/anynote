import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/l10n/app_localizations.dart';
import 'package:anynote/core/theme/app_theme.dart';

import 'test_app_helper.dart';

/// Renders screens to PNG files so design can be reviewed — and compared
/// before and after a change — without a device.
///
/// `flutter test` draws text with a blocky test font, has no system fonts
/// for Chinese to fall back to, does not fall back glyph by glyph inside a
/// font family, and loads no icon font. So [loadAppFonts] registers faces
/// that carry the needed coverage in one file each. Build them once with
/// `python3 tool/design-fonts/build_fonts.py build/design-fonts` (see the
/// script for the Python packages it needs).
///
/// Images land in `build/design-gallery/<name>.png` (git-ignored).

/// Logical size of a large phone, close to the Note 9 the app is tested on.
const kPhoneSize = Size(412, 869);
const kPhoneDpr = 2.625;

/// Where the images go, relative to the frontend directory.
const kGalleryDir = 'build/design-gallery';

/// The merged faces, written by tool/design-fonts/build_fonts.py.
const kFontDir = 'build/design-fonts';

final GlobalKey _rootKey = GlobalKey();

bool _fontsLoaded = false;

/// Loads the merged faces when they have been built; otherwise the app's
/// own font files, which leaves Chinese and icons as empty boxes.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  final manifest = File('$kFontDir/manifest.json');
  final Map<String, List<String>> families;
  if (manifest.existsSync()) {
    final decoded = jsonDecode(manifest.readAsStringSync()) as Map;
    families = {
      for (final entry in decoded.entries)
        entry.key as String: [
          for (final file in entry.value as List) '$kFontDir/$file',
        ],
    };
    for (final paths in families.values) {
      for (final path in paths) {
        assert(File(path).existsSync(), 'Run tool/design-fonts/build_fonts.py');
      }
    }
  } else {
    const own = <String, List<String>>{
      'Inter': [
        'assets/fonts/inter/Inter-Regular.otf',
        'assets/fonts/inter/Inter-SemiBold.otf',
        'assets/fonts/inter/Inter-Bold.otf',
      ],
      'Caveat': ['assets/fonts/caveat/Caveat.ttf'],
      'RobotoMono': ['assets/fonts/roboto-mono/RobotoMono.ttf'],
    };
    families = own;
  }

  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      final bytes = await File(path).readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  for (final entry in families.entries) {
    await load(entry.key, entry.value);
  }

  // `AppIcons` draws through the phosphor_flutter package's fonts, which a
  // test does not load either. A package font is registered under
  // "packages/<package>/<family>".
  final pubCache = Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['HOME']}/.pub-cache';
  final packages = Directory('$pubCache/hosted/pub.dev');
  if (packages.existsSync()) {
    for (final package in packages.listSync()) {
      if (!package.path.contains('phosphor_flutter-')) continue;
      final fonts = Directory('${package.path}/lib/fonts');
      if (!fonts.existsSync()) continue;
      for (final file in fonts.listSync()) {
        final family = switch (file.uri.pathSegments.last) {
          'Phosphor.ttf' => 'Regular',
          'Phosphor-Fill.ttf' => 'Fill',
          'Phosphor-Bold.ttf' => 'Bold',
          _ => null,
        };
        if (family != null) {
          await load('packages/phosphor_flutter/Phosphor$family', [file.path]);
        }
      }
    }
  }
  _fontsLoaded = true;
}

/// Sizes the test surface to a phone. Call once per test, before pumping.
void usePhoneSurface(WidgetTester tester, {bool dark = false}) {
  tester.view.physicalSize = kPhoneSize * kPhoneDpr;
  tester.view.devicePixelRatio = kPhoneDpr;
  tester.platformDispatcher.platformBrightnessTestValue =
      dark ? Brightness.dark : Brightness.light;
}

void resetPhoneSurface(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
  tester.platformDispatcher.clearPlatformBrightnessTestValue();
}

/// The app's own theme, localizations and text scaling around [screen],
/// the way `main.dart` assembles it, minus the router.
///
/// The whole app is one repaint boundary, so sheets, menus and dialogs are
/// in the picture too.
Widget galleryApp(
  Widget screen, {
  bool dark = false,
  Locale locale = const Locale('zh'),
  double textScale = 1.0,
}) {
  return RepaintBoundary(
    key: _rootKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        quill.FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: screen,
    ),
  );
}

/// Lets real asynchronous work (database, streams) run, then plays out
/// entrance animations. Not `pumpAndSettle`: several screens animate
/// forever, which would never settle.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Writes the current frame to `build/design-gallery/<name>.png`.
Future<void> capture(WidgetTester tester, String name) async {
  await settle(tester);
  final boundary =
      _rootKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) {
    fail('Nothing to capture: galleryApp() is not on screen');
  }
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$kGalleryDir/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

/// A database holding notes that look like a real week of use: varied
/// lengths, Chinese and English, lists, a very long title, Markdown.
Future<AppDatabase> seededDatabase() async {
  final db = createTestDatabase();
  for (final note in kSampleNotes) {
    final id = await db.notesDao.createNote(
      id: note.id,
      encryptedContent: 'enc_${note.body}',
      plainContent: note.body,
      plainTitle: note.title,
      encryptedTitle: 'enc_${note.title}',
    );
    if (note.starred == true) {
      await db.notesDao.togglePin(id);
    }
  }
  return db;
}

/// A note as the app stores it: the first line of the body is the title
/// (the editor derives it that way), so the card shows it as its heading.
class SampleNote {
  const SampleNote(this.id, this.body, {this.starred});

  final String id;
  final String body;
  final bool? starred;

  String get title => body.split('\n').first;
}

const kSampleNotes = <SampleNote>[
  SampleNote(
    'n-weekly',
    '周会记录 11/18\n'
        '参加：老张、小李、我\n'
        '\n'
        '1. 发布功能这周收尾，周四提测。\n'
        '2. 小红书标题超长的问题要在编辑器里就提示。\n'
        '3. 下周开始看数据回流的事。\n'
        '\n'
        '我的行动项：补一份平台规则说明。',
    starred: true,
  ),
  SampleNote(
    'n-book',
    '读《置身事内》\n'
        '第三章讲地方政府的债务。土地财政不是简单的卖地，而是把未来的'
        '土地收益抵押到今天用。\n'
        '\n'
        '- 城投公司是政府融资的平台\n'
        '- 债务本身不可怕，可怕的是收益覆盖不了利息\n'
        '\n'
        '联想到公司里的预算，也是同样的逻辑。',
  ),
  SampleNote(
    'n-trip',
    '三亚旅行清单\n'
        '12/2 出发，12/6 回\n'
        '\n'
        '[ ] 防晒霜（SPF50）\n'
        '[ ] 泳衣、浮潜面镜\n'
        '[ ] 充电宝、转换插头\n'
        '[ ] 晕船药\n'
        '\n'
        '想去的：后海村、亚特兰蒂斯、第一市场。',
  ),
  SampleNote(
    'n-idea',
    '灵感：把零散笔记整理成一篇能发布的文章\n'
        '平时记的东西很碎，开会、读书、路上想到的。要是能选几条，让 AI '
        '按平台整理成小红书或公众号的文章，再手动改一改就能发，会省很多事。\n'
        '\n'
        '关键点：\n'
        '1. 先按主题聚类\n'
        '2. 每个平台有自己的写法和字数限制\n'
        '3. 发布前要检查违禁词',
  ),
  SampleNote(
    'n-gym',
    '这周的训练\n'
        '周一 胸 + 三头\n'
        '周三 背 + 二头\n'
        '周五 腿\n'
        '周日 休息\n'
        '\n'
        '体重 72.4kg，比上月轻了 1.2。',
  ),
  SampleNote(
    'n-english',
    'Weekend ideas\n'
        'Farmers market on Saturday morning.\n'
        'Try the new noodle place on Wulumuqi Road.\n'
        'Finish the draft before Sunday evening.',
  ),
  SampleNote(
    'n-long-title',
    '关于把家里那台旧打印机修好这件事我拖了整整三个月最后发现只是卡纸了\n'
        '原来只是卡纸。',
  ),
  SampleNote(
    'n-markdown',
    'Markdown 语法速查\n'
        '# 标题\n'
        '\n'
        '**加粗** 和 *斜体*\n'
        '\n'
        '- 列表项\n'
        '- 列表项\n'
        '\n'
        '> 引用一句话\n'
        '\n'
        '```\n'
        'code();\n'
        '```\n'
        '\n'
        '| 列一 | 列二 |\n'
        '| --- | --- |\n'
        '| a | b |',
  ),
  SampleNote(
    'n-meeting',
    '和设计师过稿\n登录页的第三方登录按钮先去掉。设置页的分组标题字号再小一点。',
  ),
  SampleNote(
    'n-quote',
    '写不出来的时候\n就先把昨天的事记下来。',
  ),
];
