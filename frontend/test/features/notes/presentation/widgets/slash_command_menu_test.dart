import 'package:anynote/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/widgets/slash_command_menu.dart';
import 'package:anynote/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SlashCommandType enum', () {
    test('contains all expected types', () {
      final expectedNames = <String>[
        'heading1',
        'heading2',
        'heading3',
        'bulletList',
        'numberedList',
        'todoList',
        'codeBlock',
        'quote',
        'divider',
        'table',
        'image',
        'wikilink',
        'transclusion',
        'callout',
        'mermaid',
        'snippet',
      ];

      for (final name in expectedNames) {
        expect(
          SlashCommandType.values.any((t) => t.name == name),
          isTrue,
          reason: 'Missing SlashCommandType.$name',
        );
      }
    });

    test('has exactly 16 types', () {
      expect(SlashCommandType.values.length, 16);
    });
  });

  group('buildSlashCommands', () {
    testWidgets('returns all 16 commands', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              final commands = buildSlashCommands(context);
              expect(commands.length, 16);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('all command names are non-empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              final commands = buildSlashCommands(context);
              for (final cmd in commands) {
                expect(
                  cmd.name.isNotEmpty,
                  isTrue,
                  reason: 'Command ${cmd.type} has empty name',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('all command descriptions are non-empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              final commands = buildSlashCommands(context);
              for (final cmd in commands) {
                expect(
                  cmd.description.isNotEmpty,
                  isTrue,
                  reason: 'Command ${cmd.type} has empty description',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('each SlashCommandType is represented exactly once',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              final commands = buildSlashCommands(context);
              final types = commands.map((c) => c.type).toSet().toList();
              expect(types.length, SlashCommandType.values.length);
              for (final t in SlashCommandType.values) {
                expect(
                  types.contains(t),
                  isTrue,
                  reason: 'Missing type $t in command list',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('filter function correctly narrows results', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              final commands = buildSlashCommands(context);
              // Simulate the filter logic used in SlashCommandMenuState.
              const filter = 'heading';
              final filtered = commands
                  .where(
                    (cmd) =>
                        cmd.name.toLowerCase().contains(filter.toLowerCase()),
                  )
                  .toList();

              // Should match the three heading commands.
              expect(filtered.length, 3);
              expect(
                filtered.every(
                  (c) =>
                      c.type == SlashCommandType.heading1 ||
                      c.type == SlashCommandType.heading2 ||
                      c.type == SlashCommandType.heading3,
                ),
                isTrue,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('filter returns empty for non-matching query', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              final commands = buildSlashCommands(context);
              final filtered = commands
                  .where(
                    (cmd) => cmd.name.toLowerCase().contains('zzzznonexistent'),
                  )
                  .toList();

              expect(filtered, isEmpty);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('commands have expected icons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              final commands = buildSlashCommands(context);
              final iconMap = {
                SlashCommandType.heading1: AppIcons.title,
                SlashCommandType.heading2: AppIcons.title,
                SlashCommandType.heading3: AppIcons.title,
                SlashCommandType.bulletList: AppIcons.bulletList,
                SlashCommandType.numberedList: AppIcons.numberedList,
                SlashCommandType.todoList: AppIcons.checkBox,
                SlashCommandType.codeBlock: AppIcons.code,
                SlashCommandType.quote: AppIcons.quote,
                SlashCommandType.divider: AppIcons.remove,
                SlashCommandType.table: AppIcons.tableChart,
                SlashCommandType.image: AppIcons.imageIcon,
                SlashCommandType.wikilink: AppIcons.link,
                SlashCommandType.transclusion: AppIcons.insertLink,
                SlashCommandType.callout: AppIcons.infoOutline,
                SlashCommandType.mermaid: AppIcons.accountTree,
                SlashCommandType.snippet: AppIcons.code,
              };
              for (final cmd in commands) {
                expect(
                  cmd.icon,
                  iconMap[cmd.type],
                  reason: '${cmd.type} has unexpected icon',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });

  group('SlashCommand data class', () {
    test('holds expected fields', () {
      const cmd = SlashCommand(
        name: 'Test',
        description: 'desc',
        icon: AppIcons.add,
        type: SlashCommandType.divider,
      );

      expect(cmd.name, 'Test');
      expect(cmd.description, 'desc');
      expect(cmd.icon, AppIcons.add);
      expect(cmd.type, SlashCommandType.divider);
    });
  });
}
