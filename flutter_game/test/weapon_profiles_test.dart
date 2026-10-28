import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/gear_icon_art.dart';
import 'package:guardian_new/melee_weapon_art.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/weapon_profiles.dart';

Future<Uint8List> raster(
  void Function(ui.Canvas) paint, {
  int side = 256,
}) async {
  final recorder = ui.PictureRecorder();
  paint(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(side, side);
  picture.dispose();
  final bytes = (await image.toByteData())!.buffer.asUint8List();
  final result = Uint8List.fromList(bytes);
  image.dispose();
  return result;
}

void link(TimedWeaponCombo combo, WeaponComboProfile profile) {
  final window = combo.window!;
  combo.advance(profile.barDuration * ((window.start + window.end) / 2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all melee weapons have unique effects and preserve the old atlas IDs',
    () {
      expect(gearCatalog.length, 34);
      expect(gearCatalog[23].id, 'sentinel');
      final melee = gearCatalog.where(
        (g) =>
            g.slot == GearSlot.weapon &&
            g.heroClass == HeroClass.warrior &&
            !g.isThrowingWeapon,
      );
      expect(melee.length, 16);
      expect(melee.every((g) => g.comboProfile != null), true);
      expect(melee.map((g) => g.comboProfile!.effect).toSet().length, 16);
      expect(melee.map((g) => g.comboProfile!.chainLength).toSet().length, 6);
    },
  );

  test(
    'every opening picks a stable random target entirely after the first third',
    () {
      for (final profile in meleeWeaponProfiles.values) {
        final combo = TimedWeaponCombo(random: math.Random(479));
        final openings = <double>{};
        for (var i = 0; i < 25; i++) {
          combo.reset();
          combo.press(profile);
          final window = combo.window!;
          expect(window.start, greaterThanOrEqualTo(1 / 3));
          expect(window.end, lessThanOrEqualTo(.94 + .000001));
          expect(
            window.end - window.start,
            closeTo(profile.windowWidth, .000001),
          );
          openings.add(window.start);
          combo.advance(profile.barDuration * .15);
          expect(identical(combo.window, window), true);
        }
        expect(openings.length, greaterThan(20), reason: profile.id);
        if (!profile.endless) {
          expect(profile.chainLength, inInclusiveRange(4, 8));
        }
      }
    },
  );

  test(
    'new weapons enter loot, level-gated shops and real equipment saves',
    () {
      final p = Progress(), mage = Progress(heroClass: HeroClass.mage);
      final observed = <String>{};
      final random = math.Random(313);
      for (var i = 0; i < 1500; i++) {
        observed.add(p.rollLoot(random, elite: true).base.id);
      }
      for (final def in gearCatalog.skip(24)) {
        expect(observed, contains(def.id));
        expect(mage.shopGear, isNot(contains(def)));
        final required =
            const {'dualblades', 'rapier', 'throwingaxes'}.contains(def.id)
            ? 1
            : const {'katana', 'flail', 'javelin'}.contains(def.id)
            ? 3
            : 5;
        p.level = required - 1;
        if (required > 1) expect(p.shopGear, isNot(contains(def)));
        p.level = required;
        expect(p.shopGear, contains(def));
        final item = p.createGear(def, rarity: Rarity.rare);
        p.inventory.add(item);
        expect(p.equip(item), true);
        final restored = Progress.fromSave(p.toSave())!;
        expect(restored.weapon.base.id, def.id);
        if (def.isThrowingWeapon) {
          expect(restored.weapon.base.isThrowingWeapon, true);
          expect(
            restored.weapon.base.throwingProfile,
            same(def.throwingProfile),
          );
          expect(restored.weapon.base.comboProfile, isNull);
        } else {
          expect(
            restored.weapon.base.comboProfile!.effect,
            def.comboProfile!.effect,
          );
        }
      }
    },
  );

  test(
    'finite combo requires every timing and only the last success finishes',
    () {
      final profile = meleeWeaponProfiles['shortsword']!;
      final combo = TimedWeaponCombo();
      expect(combo.press(profile).kind, ComboPress.started);
      expect(combo.press(profile).kind, ComboPress.missed);
      expect(combo.active, false);
      combo.press(profile);
      link(combo, profile);
      expect(combo.press(profile).kind, ComboPress.linked);
      while (combo.count < profile.chainLength! - 1) {
        link(combo, profile);
        expect(combo.press(profile).kind, ComboPress.linked);
      }
      link(combo, profile);
      final finish = combo.press(profile);
      expect(finish.kind, ComboPress.finisher);
      expect(finish.count, profile.chainLength);
      expect(combo.active, false);
      combo.press(profile);
      combo.advance(profile.barDuration + .01);
      expect(combo.active, false);
    },
  );

  test(
    'dual blades shift a fast window, remain endless and reward every third',
    () {
      final profile = meleeWeaponProfiles['dualblades']!;
      expect(profile.barDuration, lessThan(.5));
      expect(profile.windowFor(2).start, isNot(profile.windowFor(3).start));
      final combo = TimedWeaponCombo();
      combo.press(profile);
      final procs = <int>[];
      for (var i = 2; i <= 30; i++) {
        link(combo, profile);
        final result = combo.press(profile, hasTripletTrait: true);
        expect(result.kind, ComboPress.linked);
        expect(result.count, i);
        if (result.tripletProc) procs.add(i);
      }
      expect(procs, [3, 6, 9, 12, 15, 18, 21, 24, 27, 30]);
      final before = combo.progress;
      combo.advance(0);
      combo.advance(double.nan);
      expect(combo.progress, before);
      expect(combo.press(meleeWeaponProfiles['axe']!).kind, ComboPress.started);
      expect(combo.count, 1);
    },
  );

  test(
    'each melee swing has distinct pixels and leaves the hero body readable',
    () async {
      final frames = <String>{};
      for (final profile in meleeWeaponProfiles.values) {
        final bytes = await raster((c) {
          paintMeleeWeaponSwing(
            c,
            const ui.Offset(128, 128),
            profile,
            phase: .35,
            bearing: -.9,
            reach: 150,
            pose: 1,
            rank: 5,
          );
        });
        expect(bytes.where((b) => b != 0), isNotEmpty, reason: profile.id);
        frames.add(base64Encode(bytes));
        for (var y = 84; y < 115; y++) {
          for (var x = 121; x < 136; x++) {
            expect(bytes[(y * 256 + x) * 4 + 3], 0, reason: profile.id);
          }
        }
      }
      expect(frames.length, 16);
    },
  );

  test(
    'new weapon icons are distinct, contained and share no invalid atlas row',
    () async {
      final frames = <String>{};
      for (final gear in gearCatalog.skip(24)) {
        final bytes = await raster((c) {
          expect(
            GearIconArt.paintExpanded(
              c,
              const ui.Rect.fromLTWH(8, 8, 80, 80),
              gear,
            ),
            true,
          );
        }, side: 96);
        frames.add(base64Encode(bytes));
        var visible = 0;
        for (var y = 0; y < 96; y++) {
          for (var x = 0; x < 96; x++) {
            final alpha = bytes[(y * 96 + x) * 4 + 3];
            if (alpha > 0) visible++;
            if (x < 5 || x > 90 || y < 5 || y > 90) {
              expect(alpha, 0, reason: gear.id);
            }
          }
        }
        expect(visible, greaterThan(100), reason: gear.id);
      }
      expect(frames.length, 10);
    },
  );
}
