import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/main.dart';
import 'package:guardian_new/title_screen.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

class _ReleaseBundle extends CachingAssetBundle {
  bool unavailable = false;
  @override
  Future<ByteData> load(String key) {
    if (unavailable) {
      throw StateError('The previous release has left the server');
    }
    return rootBundle.load(key);
  }
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 800; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    if (ready()) return;
  }
  fail('The finale did not become ready');
}

Adventure _session(WidgetTester tester) =>
    (tester.widget<BonfireWidget>(find.byType(BonfireWidget)).player!
            as Guardian)
        .session;

GameCheckpoint _finaleSave(TimePath path) {
  final source = Adventure(GameArt(), stage: WorldStage.convergence)
    ..timePath = path
    ..start(TestGame());
  try {
    return GameCheckpoint.capture(source)!;
  } finally {
    source.dispose();
  }
}

Future<Uint8List> _giverPixels(Adventure session) async {
  final recorder = ui.PictureRecorder();
  ui.Picture? picture;
  try {
    final canvas = ui.Canvas(recorder)..translate(50, 90);
    VillagePerson(session, false).render(canvas);
    picture = recorder.endRecording();
    final image = await picture.toImage(128, 160);
    try {
      return (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    if (recorder.isRecording) recorder.endRecording().dispose();
    picture?.dispose();
  }
}

void main() {
  testWidgets(
    'both finale branches start with their actual giver and keep the journal after release removal',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final npcPictures = <Uint8List>[];
      final artwork = <GameArt>[];
      addTearDown(() {
        for (final art in artwork) {
          art.dispose();
        }
      });
      for (final path in TimePath.values) {
        final bundle = _ReleaseBundle();
        final art = (await tester.runAsync(
          () => GameArt.loadMenu(bundle: bundle),
        ))!;
        artwork.add(art);
        var saved = _finaleSave(path).encode();
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(path),
            home: EntryPage(
              loadArt: () async => art,
              readCheckpoint: () => saved,
              writeCheckpoint: (value) {
                saved = value;
                return true;
              },
            ),
          ),
        );
        await _until(
          tester,
          () => find.byType(TitleScreen).evaluate().isNotEmpty,
        );
        await tester.tap(find.text('이어하기'));
        await _until(
          tester,
          () =>
              find.byType(BonfireWidget).evaluate().isNotEmpty &&
              _session(tester).ready,
        );
        final session = _session(tester);
        expect(session.world.stage, WorldStage.convergence);
        expect(session.timePath, path);
        expect(
          session.stageContract!.actor,
          path == TimePath.past ? 'villager' : 'gunner',
        );
        bundle.unavailable = true;
        final pixels = (await tester.runAsync(() => _giverPixels(session)))!;
        expect(pixels.any((value) => value != 0), isTrue);
        npcPictures.add(pixels);
        await tester.tap(
          find.byWidgetPredicate(
            (widget) => widget is MenuButton && widget.label == '여정',
          ),
        );
        await tester.pump();
        expect(find.textContaining(session.stageContract!.giver), findsWidgets);
        expect(tester.takeException(), isNull);
        expect(GameCheckpoint.decode(saved)!.data['stage'], 'convergence');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
      expect(
        listEquals(npcPictures[0], npcPictures[1]),
        isFalse,
        reason: 'the two branches must paint their different actual givers',
      );
    },
  );
}
