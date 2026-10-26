import 'dart:io';
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';
import 'package:bonfire/camera/bonfire_camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/rpg_widgets.dart';

import 'support/test_game.dart';

class _Camera extends BonfireCamera {
  ui.Rect view = ui.Rect.zero;
  @override
  ui.Rect get visibleWorldRect => view;
}

class _Game extends TestGame {
  @override
  final _Camera camera = _Camera();
}

class _CountingLoot extends GroundLoot {
  _CountingLoot(super.session, super.item, super.at);
  int draws = 0, removalRequests = 0;
  @override
  void render(ui.Canvas canvas) {
    draws++;
    super.render(canvas);
  }

  @override
  void removeFromParent() {
    removalRequests++;
    super.removeFromParent();
  }
}

Future<ui.Image> _raster(
  void Function(ui.Canvas) paint, {
  int width = 80,
  int height = 80,
}) async {
  final recorder = ui.PictureRecorder();
  paint(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  return image;
}

Future<Uint8List> _bytes(ui.Image image) async {
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ui.Image atlas;
  setUpAll(() async {
    final data = await rootBundle.load('assets/images/gear-icons.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    atlas = (await codec.getNextFrame()).image;
    codec.dispose();
  });
  tearDownAll(() => atlas.dispose());

  Adventure session({bool art = false}) {
    final s = inCombatField(Adventure(GameArt()));
    s.start(TestGame());
    if (art) s.art.images['gear-icons'] = atlas;
    addTearDown(() {
      s.art.images.clear(); // The test owns the shared atlas.
      s.dispose();
    });
    return s;
  }

  test(
    'all 24 real item crops match inventory glyphs at ground size',
    () async {
      final s = session(art: true);
      for (final base in gearCatalog) {
        final gear = s.progress.createGear(base);
        final loot = GroundLoot(s, gear, ui.Offset.zero);
        final actual = await _raster((c) {
          c.translate(40, 54);
          loot.render(c);
        });
        final expected = await _raster((c) {
          c.translate(24, 28);
          GearGlyph(gear, s.art).paint(c, const ui.Size(32, 32));
        });
        final a = await _bytes(actual), e = await _bytes(expected);
        var checked = 0;
        for (var i = 0; i < e.length; i += 4) {
          if (e[i + 3] < 245) continue;
          checked++;
          for (var channel = 0; channel < 3; channel++) {
            expect(
              (a[i + channel] - e[i + channel]).abs(),
              lessThanOrEqualTo(5),
              reason: base.id,
            );
          }
        }
        expect(checked, greaterThan(30), reason: base.id);
        actual.dispose();
        expected.dispose();
      }
    },
  );

  test(
    'rare beam stays yellow and changes continuously with simulation age',
    () async {
      final s = session(art: true);
      final loot = GroundLoot(
        s,
        s.progress.createGear(gearById('longsword'), rarity: Rarity.rare),
        ui.Offset.zero,
      );
      Future<ui.Image> frame() => _raster((c) {
        c.translate(40, 54);
        loot.render(c);
      });
      final first = await frame();
      final a = await _bytes(first);
      final beam = (20 * 80 + 40) * 4;
      expect(a[beam + 3], greaterThan(0));
      expect(a[beam], greaterThan(a[beam + 2]));
      loot.update(.05);
      final next = await frame();
      final b = await _bytes(next);
      expect(b, isNot(a));
      s.paused = true;
      final age = loot.age;
      loot.update(1);
      expect(loot.age, age);
      final paused = await frame();
      expect(await _bytes(paused), b);
      first.dispose();
      next.dispose();
      paused.dispose();
    },
  );

  test(
    'culling includes beam, left icon edge and shadow without changing TTL',
    () {
      final s = session();
      final game = _Game();
      final loot = _CountingLoot(
        s,
        s.progress.createGear(gearById('longsword'), rarity: Rarity.rare),
        const ui.Offset(6000, 4200),
      )..gameRef = game;
      final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
      game.camera.view = const ui.Rect.fromLTWH(0, 0, 100, 100);
      loot.renderTree(canvas);
      expect(loot.draws, 0);
      loot.update(.05);
      expect(loot.age, .05);
      for (final view in [
        const ui.Rect.fromLTWH(5999, 4153, 2, 3), // beam above old 20x20
        const ui.Rect.fromLTWH(5984, 4180, 2, 3), // icon left of the origin
        const ui.Rect.fromLTWH(5990, 4204, 2, 3), // shadow below icon
      ]) {
        game.camera.view = view;
        loot.renderTree(canvas);
      }
      expect(loot.draws, 3);
      expect(loot.position.toOffset(), const ui.Offset(6000, 4200));
      expect(loot.size.x, 20);
      expect(loot.size.y, 20);
      expect(loot.priority, lessThan(s.hero.priority));
      game.camera.view = const ui.Rect.fromLTWH(0, 0, 100, 100);
      loot.age = 150;
      loot.update(.05);
      expect(loot.removalRequests, 1);
      loot.renderTree(canvas);
      expect(loot.draws, 3);
      recorder.endRecording().dispose();
    },
  );

  test(
    'render preserves checkpoint identity, age, resources and reward state',
    () async {
      final s = session(art: true);
      final loot = GroundLoot(
        s,
        s.progress.createGear(gearById('longsword'), rarity: Rarity.rare),
        s.hero.body.center + const ui.Offset(100, 0),
      )..age = 74.125;
      s.loot.add(loot);
      final before = GameCheckpoint.capture(s)!.encode();
      final image = await _raster(loot.render);
      expect(GameCheckpoint.capture(s)!.encode(), before);
      final restored = GameCheckpoint.decode(before)!.restore(GameArt());
      addTearDown(restored.dispose);
      expect(restored.loot.single.age, 74.125);
      expect(restored.loot.single.item.toSave(), loot.item.toSave());
      expect(
        restored.loot.single.position.toOffset(),
        loot.position.toOffset(),
      );
      image.dispose();
    },
  );

  test('pickup still requires 85px, clear line and an active session', () {
    final s = session();
    final center = s.hero.body.center;
    final gear = s.progress.createGear(
      gearById('longsword'),
      rarity: Rarity.rare,
    );
    final loot = GroundLoot(s, gear, center + const ui.Offset(85.01, 0));
    loot.tryCollect();
    expect(loot.collected, false);
    loot.position.x -= .01;
    s.paused = true;
    loot.tryCollect();
    expect(loot.collected, false);
    s.paused = false;
    loot.tryCollect();
    expect(loot.collected, true);
    expect(
      s.progress.inventory.where((g) => g.serial == gear.serial),
      hasLength(1),
    );
    final count = s.progress.inventory.length;
    loot.tryCollect();
    expect(s.progress.inventory.length, count);

    final prop = s.world.props.firstWhere((p) => p.kind == 'tree');
    final blocked = GroundLoot(
      s,
      s.progress.createGear(gearById('amber'), rarity: Rarity.rare),
      prop.body.center,
    );
    final from = prop.body.center - const ui.Offset(50, 0);
    s.hero.position.setValues(
      from.dx - s.hero.body.width / 2,
      from.dy - s.hero.body.height / 2,
    );
    expect(
      (s.hero.body.center - blocked.position.toOffset()).distance,
      lessThan(85),
    );
    expect(
      s.world.clearLine(
        s.hero.body.center,
        blocked.position.toOffset(),
        const ui.Size(3, 3),
      ),
      false,
    );
    blocked.tryCollect();
    expect(blocked.collected, false);
  });

  test('optional native pixel proof uses the actual equipment sheet', () async {
    final directory = Platform.environment['LOOT_PROOF_DIR'];
    if (directory == null) return;
    final s = session(art: true);
    final sheet = await _raster(
      (c) {
        for (var i = 0; i < gearCatalog.length; i++) {
          final x = (i % 6) * 88.0, y = (i ~/ 6) * 96.0;
          c.drawRect(
            ui.Rect.fromLTWH(x, y, 88, 96),
            ui.Paint()
              ..color = (i ~/ 6).isEven
                  ? const ui.Color(0xff3b4932)
                  : const ui.Color(0xffad915f),
          );
          c.save();
          c.translate(x + 44, y + 70);
          GroundLoot(
            s,
            s.progress.createGear(
              gearCatalog[i],
              rarity: Rarity.values[(i ~/ 6) % 4],
            ),
            ui.Offset.zero,
          ).render(c);
          c.restore();
        }
      },
      width: 528,
      height: 384,
    );
    final phases = await _raster(
      (c) {
        for (final rarity in Rarity.values) {
          for (var i = 0; i < 6; i++) {
            final x = i * 88.0, y = rarity.index * 96.0;
            c.drawRect(
              ui.Rect.fromLTWH(x, y, 88, 96),
              ui.Paint()
                ..color = rarity.index.isEven
                    ? const ui.Color(0xff3b4932)
                    : const ui.Color(0xffad915f),
            );
            c.save();
            c.translate(x + 44, y + 70);
            final gear = Gear(31, gearById('longsword'), rarity: rarity);
            (GroundLoot(s, gear, ui.Offset.zero)..age = i * .3).render(c);
            c.restore();
          }
        }
      },
      width: 528,
      height: 384,
    );
    await Directory(directory).create(recursive: true);
    for (final entry in {
      'ground-loot-all-gear': sheet,
      'ground-loot-light-phases': phases,
    }.entries) {
      final png = (await entry.value.toByteData(
        format: ui.ImageByteFormat.png,
      ))!;
      await File(
        '$directory/${entry.key}.png',
      ).writeAsBytes(png.buffer.asUint8List());
      entry.value.dispose();
    }
  });
}
