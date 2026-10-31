import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/class_selection.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/landscape_entry.dart';
import 'package:guardian_new/main.dart';
import 'package:guardian_new/title_screen.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

class _PendingArt extends GameArt {
  final gate = Completer<void>();
  int preparations = 0;
  @override
  Future<void> ensureStage(
    WorldStage stage, {
    required HeroClass heroClass,
    Iterable<String> enemyKinds = const [],
    bool cave = false,
  }) async {
    preparations++;
    await gate.future;
    throw StateError('Test preparation failure');
  }
}

void main() {
  for (final size in [
    const Size(320, 420),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets('title buttons fit $size and unavailable save is disabled', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var starts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(1.3),
            ),
            child: TitleScreen(onStart: () => starts++),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final artwork = find.byType(FittedBox);
      expect(tester.widget<FittedBox>(artwork).fit, BoxFit.cover);
      final bounds = tester.getRect(artwork);
      expect(bounds.left, closeTo(0, .01));
      expect(bounds.top, closeTo(0, .01));
      expect(bounds.right, closeTo(size.width, .01));
      expect(bounds.bottom, closeTo(size.height, .01));
      expect(
        tester
            .widget<EntryHotspot>(find.byKey(const ValueKey('title-continue')))
            .onTap,
        isNull,
      );
      for (final key in ['title-start', 'title-continue']) {
        final rect = tester.getRect(find.byKey(ValueKey(key)));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
        expect(rect.height, greaterThanOrEqualTo(44));
      }
      await tester.tap(find.byKey(const ValueKey('title-start')));
      expect(starts, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cancel and class-selection back preserve checkpoint and title', (
    tester,
  ) async {
    final source = Adventure(GameArt())..start(TestGame());
    final stored = GameCheckpoint.capture(source)!.encode();
    source.dispose();
    var writes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: EntryPage(
          loadArt: () async => GameArt(),
          readCheckpoint: () => stored,
          writeCheckpoint: (_) {
            writes++;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('title-start')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.byType(TitleScreen), findsOneWidget);
    expect(writes, 0);
    await tester.tap(find.byKey(const ValueKey('title-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('새 모험'));
    await tester.pumpAndSettle();
    expect(find.byType(ClassSelection), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('select-back')));
    await tester.pumpAndSettle();
    expect(find.byType(TitleScreen), findsOneWidget);
    expect(
      tester
          .widget<EntryHotspot>(find.byKey(const ValueKey('title-continue')))
          .onTap,
      isNotNull,
    );
    expect(writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rapid start and resume activate one preparation and failure preserves save',
    (tester) async {
      final source = Adventure(GameArt())..start(TestGame());
      final stored = GameCheckpoint.capture(source)!.encode();
      source.dispose();
      final art = _PendingArt();
      var writes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: EntryPage(
            loadArt: () async => art,
            readCheckpoint: () => stored,
            writeCheckpoint: (_) {
              writes++;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final title = tester.widget<TitleScreen>(find.byType(TitleScreen));
      title.onStart();
      title.onStart();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      title.onContinue!();
      title.onContinue!();
      await tester.pump();
      expect(art.preparations, 1);
      expect(writes, 0);
      art.gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(TitleScreen), findsOneWidget);
      expect(writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
