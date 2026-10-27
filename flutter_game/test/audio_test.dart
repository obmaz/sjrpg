import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/audio_bridge.dart';
import 'package:guardian_new/audio_settings.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

class FakeAudio implements AudioBridge {
  @override
  bool supported = true;
  @override
  bool visible = true;
  bool enabled = true, fail = false;
  int stops = 0;
  final sounds = <EffectSound>[];
  final preferences = <String, String>{};
  @override
  String? readPreference(String key) => preferences[key];
  @override
  void writePreference(String key, String value) => preferences[key] = value;
  @override
  void setEnabled(bool value) => enabled = value;
  @override
  void play(EffectSound sound) {
    if (fail) throw StateError('browser rejected playback');
    if (enabled) sounds.add(sound);
  }

  @override
  void stop() => stops++;
  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'dense hits are limited while hurt takes priority and stop clears the burst',
    () {
      var time = Duration.zero;
      final bridge = FakeAudio();
      final audio = AudioSettings(bridge: bridge, now: () => time);
      addTearDown(audio.dispose);
      for (var i = 0; i < 20; i++) {
        audio.play(EffectSound.impact);
      }
      expect(bridge.sounds, [EffectSound.impact]);
      audio.play(EffectSound.hurt);
      expect(bridge.sounds.last, EffectSound.hurt);
      time += const Duration(milliseconds: 81);
      audio.play(EffectSound.impact);
      expect(bridge.sounds.length, 3);
      audio.stop();
      audio.play(EffectSound.ice);
      expect(bridge.sounds.last, EffectSound.ice);
      expect(bridge.stops, 1);
    },
  );
  test(
    'mute persists, preview respects mute and unavailable or hidden outputs stay silent',
    () {
      final bridge = FakeAudio();
      final audio = AudioSettings(bridge: bridge);
      audio.setEnabled(false);
      audio.play(EffectSound.slash, preview: true);
      expect(bridge.sounds, isEmpty);
      expect(bridge.stops, 1);
      audio.dispose();
      final restored = AudioSettings(bridge: bridge);
      addTearDown(restored.dispose);
      expect(restored.enabled, false);
      restored.setEnabled(true);
      bridge.supported = false;
      restored.play(EffectSound.fire, preview: true);
      bridge.supported = true;
      bridge.visible = false;
      restored.play(EffectSound.fire, preview: true);
      expect(bridge.sounds, isEmpty);
      bridge.visible = true;
      restored.play(EffectSound.fire, preview: true);
      expect(bridge.sounds, [EffectSound.fire]);
    },
  );
  test(
    'sound profiles are distinct, short and bounded for overlapping combat',
    () {
      final profiles = EffectSound.values.map(SoundProfile.forSound).toList();
      expect(
        profiles
            .map((p) => (p.pitch, p.endPitch, p.duration, p.noiseFrequency))
            .toSet()
            .length,
        EffectSound.values.length,
      );
      for (final p in profiles) {
        expect(p.duration, inInclusiveRange(.08, .4));
        expect(p.pitch, inInclusiveRange(30, 2000));
        expect(p.endPitch, inInclusiveRange(30, 2000));
        expect(p.toneGain, inInclusiveRange(0, .1));
        expect(p.noiseGain, inInclusiveRange(0, .2));
      }
    },
  );
  test(
    'only successful actions play, pause and disposal stop sound, audio failures preserve combat',
    () {
      var time = Duration.zero;
      final bridge = FakeAudio();
      final audio = AudioSettings(bridge: bridge, now: () => time);
      addTearDown(audio.dispose);
      final s = inCombatField(Adventure(GameArt(), audio: audio))
        ..start(TestGame());
      s.hero.slash();
      s.hero.slash();
      expect(bridge.sounds, [EffectSound.slash]);
      s.pause();
      time += const Duration(seconds: 1);
      s.hero.attackClock = 0;
      s.hero.slash();
      s.hero.skill();
      s.hurtHero(5);
      expect(bridge.sounds.length, 1);
      expect(bridge.stops, 1);
      s.resume();
      s.hero.skill();
      expect(bridge.sounds.last, EffectSound.warcry);
      time += const Duration(seconds: 1);
      final count = bridge.sounds.length;
      s.hero.skill();
      expect(
        bridge.sounds.length,
        count,
        reason: 'cooldown rejection is silent',
      );
      s.hurtHero(5);
      expect(bridge.sounds.last, EffectSound.hurt);
      s.hurtHero(5);
      expect(bridge.sounds.length, count + 1);
      bridge.fail = true;
      final victim = s.mobs.first, hp = s.mobs.first.life.value;
      s.hit(victim, 5, Offset.zero);
      expect(victim.life.value, lessThan(hp));
      s.dispose();
      expect(bridge.stops, 2);
      s.hero.slash();
      expect(bridge.sounds.length, count + 1);
    },
  );
  test('mage basic attacks follow the equipped weapon element', () {
    final bridge = FakeAudio();
    var time = Duration.zero;
    final audio = AudioSettings(bridge: bridge, now: () => time);
    addTearDown(audio.dispose);
    final s = inCombatField(
      Adventure(GameArt(), heroClass: HeroClass.mage, audio: audio),
    )..start(TestGame());
    addTearDown(s.dispose);
    for (final (id, sound) in [
      ('wand', EffectSound.fire),
      ('frostwand', EffectSound.ice),
      ('stormrod', EffectSound.lightning),
    ]) {
      final item = s.progress.createGear(gearById(id));
      s.progress.inventory.add(item);
      expect(s.progress.equip(item), true);
      for (var i = 0; i < 20 && s.hero.castLock > 0; i++) {
        s.hero.update(.05);
      }
      expect(s.hero.castLock, 0);
      s.hero.attackClock = 0;
      s.hero.slash();
      expect(bridge.sounds.last, sound);
      time += const Duration(seconds: 1);
    }
  });
}
