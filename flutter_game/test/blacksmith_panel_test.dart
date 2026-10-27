import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/blacksmith_panel.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/panel_controls.dart';
import 'package:guardian_new/sanctuary_fence.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

final _proofDirectory = Platform.environment['SJRPG_SMITH_PROOF_DIR'];

Future<void> _writeProof(ui.Image image, String name) async {
  final directory = _proofDirectory;
  if (directory == null) return;
  Directory(directory).createSync(recursive: true);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  File('$directory/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
}

class _Roll implements math.Random {
  _Roll(this.value);
  final double value;
  int calls = 0;
  @override
  double nextDouble() {
    calls++;
    return value;
  }

  @override
  bool nextBool() => value < .5;
  @override
  int nextInt(int max) => 0;
}

class _SmithAdventure extends Adventure {
  _SmithAdventure(super.art, _Roll random) : _roll = random;
  final _Roll _roll;
  @override
  _Roll get random => _roll;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GameArt? artwork;
  Future<GameArt> art(WidgetTester tester) async {
    return artwork ??= (await tester.runAsync(() async {
      final font = FontLoader('Guardian')
        ..addFont(rootBundle.load('assets-fonts/NanumGothic-Regular.ttf'));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final a = await GameArt.loadMenu();
      await a.ensureStage(WorldStage.forest, heroClass: HeroClass.warrior);
      return a;
    }))!;
  }

  tearDownAll(() => artwork?.dispose());
  _SmithAdventure session(GameArt art, _Roll roll) {
    final s = _SmithAdventure(art, roll)..start(TestGame());
    final at = s.world.blacksmithAt + const ui.Offset(0, 60);
    s.hero.position.setValues(at.dx, at.dy);
    s.progress.gold = 10000;
    s.pause();
    addTearDown(s.dispose);
    return s;
  }

  Future<void> mount(
    WidgetTester tester,
    Adventure s, {
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Guardian'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: const ValueKey('smith-proof'),
          child: Scaffold(
            body: BlacksmithPanel(session: s, onClose: () {}),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder action() =>
      find.byWidgetPredicate((w) => w is GameAction && w.primary);

  for (final size in [
    const Size(390, 844),
    const Size(320, 420),
    const Size(844, 390),
  ]) {
    testWidgets('smith sheet aligns at $size with readable scaled text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = session(await art(tester), _Roll(0));
      await mount(tester, s, scale: 1.3);
      expect(find.text('실패 시 선택한 무기 소멸'), findsOneWidget);
      expect(find.textContaining('성공 70%'), findsOneWidget);
      final stickyChance = tester.getRect(
        find.byKey(const ValueKey('smith-success-chance')),
      );
      expect(stickyChance.top, greaterThanOrEqualTo(0));
      expect(stickyChance.bottom, lessThan(size.height));
      expect(stickyChance.left, greaterThanOrEqualTo(10));
      expect(stickyChance.right, lessThanOrEqualTo(size.width - 10));
      expect(
        find.byKey(const ValueKey('smith-success-chance')).hitTestable(),
        findsOneWidget,
        reason:
            'success probability must stay visible beside the active purchase',
      );
      expect(find.textContaining('비용 37 G'), findsOneWidget);
      final stickyCost = tester.getRect(
        find.byKey(const ValueKey('smith-enhancement-cost')),
      );
      expect(stickyCost.top, greaterThanOrEqualTo(0));
      expect(stickyCost.bottom, lessThan(size.height));
      expect(stickyCost.left, greaterThanOrEqualTo(10));
      expect(stickyCost.right, lessThanOrEqualTo(size.width - 10));
      expect(
        find.byKey(const ValueKey('smith-enhancement-cost')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      if (_proofDirectory != null) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('smith-proof')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          try {
            await _writeProof(
              image,
              'panel-${size.width.toInt()}x${size.height.toInt()}',
            );
          } finally {
            image.dispose();
          }
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'one visible enhancement action spends once and retains selection on success',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = session(await art(tester), _Roll(0));
      final serial = s.progress.weapon.serial;
      final price = s.smithQuote(s.progress.weapon)!.price;
      final gold = s.progress.gold;
      await mount(tester, s);
      await tester.tap(action());
      await tester.pump();
      expect(s.progress.gold, gold - price);
      expect(s.progress.weapon.serial, serial);
      expect(s.progress.weapon.weaponLevel, 2);
      expect(find.text('강화 성공 · 무기 Lv.2'), findsOneWidget);
      expect(s.random.calls, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'destruction clears the selected item and cannot target another weapon on repeat tap',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = session(await art(tester), _Roll(.99));
      final extra = s.progress.createGear(gearById('longsword'));
      s.progress.addOwnedGear(extra);
      final victim = s.progress.weapon.serial;
      await mount(tester, s);
      await tester.tap(action());
      await tester.pump();
      expect(s.progress.inventory.any((g) => g.serial == victim), false);
      expect(s.progress.weapon.serial, extra.serial);
      expect(find.textContaining('소멸 · 다른 무기를 선택하세요'), findsOneWidget);
      final gold = s.progress.gold;
      await tester.tap(action(), warnIfMissed: false);
      await tester.pump();
      expect(s.progress.gold, gold);
      expect(s.random.calls, 1);
      expect(tester.widget<GameAction>(action()).onTap, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a changed player level rejects the displayed quote without charging or rolling',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = session(await art(tester), _Roll(0));
      await mount(tester, s);
      final gold = s.progress.gold;
      s.progress.level++;
      await tester.tap(action());
      await tester.pump();
      expect(s.progress.gold, gold);
      expect(s.random.calls, 0);
      expect(find.textContaining('상태가 바뀌었습니다'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('forge courtyard art and solid footprints stay aligned', (
    tester,
  ) async {
    final a = await art(tester);
    final s = Adventure(a)..start(TestGame());
    addTearDown(s.dispose);
    const view = ui.Rect.fromLTWH(2500, 1870, 1260, 1000);
    for (final boxes in [false, true]) {
      final recorder = ui.PictureRecorder();
      final c = ui.Canvas(recorder)..translate(-view.left, -view.top);
      s.terrain.render(c, view);
      for (final p
          in [
              ...s.world.props,
              ...s.world.campProps,
            ].where((p) => view.overlaps(p.body.inflate(220))).toList()
            ..sort((a, b) => a.body.bottom.compareTo(b.body.bottom))) {
        a.prop(c, p);
      }
      for (final section in s.world.sanctuaryFences) {
        final fence = SanctuaryFence(section, WorldStage.forest);
        c.save();
        c.translate(fence.position.x, fence.position.y);
        fence.render(c);
        c.restore();
      }
      a.actor(c, 'merchant', s.world.blacksmithAt, 1.57, 0, 68);
      a.actor(c, 'hero', s.world.spawn + const ui.Offset(14, 24), 1.57, 0, 68);
      if (boxes) {
        for (final prop in s.world.campProps) {
          for (final body in prop.collisionBodies) {
            c.drawRect(
              body,
              ui.Paint()
                ..color = const Color(0xaaff2233)
                ..style = ui.PaintingStyle.stroke
                ..strokeWidth = 2,
            );
          }
        }
      }
      final picture = recorder.endRecording();
      await tester.runAsync(() async {
        final image = await picture.toImage(1260, 1000);
        picture.dispose();
        try {
          final rgba = await image.toByteData();
          expect(rgba!.lengthInBytes, 1260 * 1000 * 4);
          expect(rgba.buffer.asUint8List().any((byte) => byte != 0), true);
          await _writeProof(image, 'village${boxes ? '-bodies' : ''}');
        } finally {
          image.dispose();
        }
      });
    }
  });

  test(
    'export genuine blacksmith checkpoints for real browser verification',
    () {
      final s = Adventure(GameArt())..start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      s.progress.level = 8;
      s.progress.gold = 10000;
      final rare = s.progress.createGear(
        gearById('longsword'),
        rarity: Rarity.rare,
        weaponLevel: 8,
      );
      final unique = s.progress.createGear(
        gearById('axe'),
        rarity: Rarity.unique,
        weaponLevel: 10,
      );
      s.progress.addOwnedGear(rare);
      s.progress.addOwnedGear(unique);
      s.progress.equip(rare);
      s.hero.position.setValues(
        s.world.blacksmithAt.dx,
        s.world.blacksmithAt.dy + 60,
      );
      final checkpoint = GameCheckpoint.capture(s)!;
      expect(GameCheckpoint.decode(checkpoint.encode()), isNotNull);
      final prefix = Platform.environment['SJRPG_SMITH_FIXTURE_PREFIX'];
      if (prefix != null) {
        File('$prefix.json').writeAsStringSync(checkpoint.encode());
        File('$prefix-meta.json').writeAsStringSync(
          jsonEncode({
            'rare': rare.serial,
            'unique': unique.serial,
            'gold': s.progress.gold,
            'heroLevel': s.progress.level,
            'rareLevel': rare.weaponLevel,
            'uniqueLevel': unique.weaponLevel,
            'rarePrice': s.smithQuote(rare)!.price,
            'rareChance': s.smithQuote(rare)!.successChance,
            'hero': {'x': s.hero.position.x, 'y': s.hero.position.y},
            'npc': {'x': s.world.blacksmithAt.dx, 'y': s.world.blacksmithAt.dy},
          }),
        );
      }
    },
  );
}
