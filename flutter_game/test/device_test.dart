import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/device_bridge.dart';
import 'package:guardian_new/device_settings.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'support/test_game.dart';

class FakeDevice implements DeviceBridge {
  @override
  bool fullscreenSupported = true;
  @override
  bool fullscreen = false;
  @override
  bool vibrationSupported = true;
  @override
  bool visible = true;
  bool failFullscreen = false, failVibration = false;
  final preferences = <String, String>{};
  final patterns = <List<int>>[];
  int cancellations = 0;
  void Function()? changed;
  @override
  String? readPreference(String key) => preferences[key];
  @override
  void writePreference(String key, String value) {
    preferences[key] = value;
  }

  @override
  Future<void> toggleFullscreen() async {
    if (failFullscreen) throw StateError('blocked by browser');
    fullscreen = !fullscreen;
    changed?.call();
  }

  @override
  bool vibrate(List<int> pattern) {
    if (failVibration) throw StateError('device rejected vibration');
    patterns.add(pattern);
    return true;
  }

  @override
  void cancelVibration() {
    cancellations++;
  }

  @override
  void listen(void Function() onChange) {
    changed = onChange;
  }

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'cleave feedback is limited while a hit on the hero takes precedence',
    () {
      final bridge = FakeDevice();
      var time = Duration.zero;
      final settings = DeviceSettings(bridge: bridge, now: () => time);
      addTearDown(settings.dispose);
      for (var i = 0; i < 12; i++) {
        settings.pulse(FeedbackKind.hit);
      }
      expect(bridge.patterns, [
        [12],
      ]);
      settings.pulse(FeedbackKind.hurt);
      expect(bridge.patterns.last, [32, 22, 45]);
      time = const Duration(milliseconds: 101);
      settings.pulse(FeedbackKind.skill);
      expect(bridge.patterns.length, 3);
      bridge.visible = false;
      time = const Duration(seconds: 1);
      settings.pulse(FeedbackKind.hit);
      expect(bridge.patterns.length, 3);
    },
  );
  test(
    'the vibration preference persists, stops active feedback and respects unsupported devices',
    () {
      final bridge = FakeDevice();
      final first = DeviceSettings(bridge: bridge);
      first.setHaptics(false);
      expect(bridge.cancellations, 1);
      first.pulse(FeedbackKind.hit, preview: true);
      expect(bridge.patterns, isEmpty);
      first.dispose();
      final restored = DeviceSettings(bridge: bridge);
      addTearDown(restored.dispose);
      expect(restored.hapticsEnabled, false);
      restored.setHaptics(true);
      bridge.vibrationSupported = false;
      restored.pulse(FeedbackKind.skill, preview: true);
      expect(bridge.patterns, isEmpty);
      bridge.vibrationSupported = true;
      restored.pulse(FeedbackKind.skill, preview: true);
      expect(bridge.patterns, [
        [12, 18, 24],
      ]);
    },
  );
  test(
    'fullscreen follows browser events and failure never claims it succeeded',
    () async {
      final bridge = FakeDevice();
      final controller = DeviceSettings(bridge: bridge);
      addTearDown(controller.dispose);
      var changes = 0;
      controller.addListener(() => changes++);
      expect(await controller.toggleFullscreen(), true);
      expect(controller.fullscreen, true);
      bridge.fullscreen = false;
      bridge.changed?.call();
      expect(controller.fullscreen, false);
      expect(changes, greaterThan(1));
      bridge.failFullscreen = true;
      expect(await controller.toggleFullscreen(), false);
      expect(controller.fullscreen, false);
      bridge.fullscreenSupported = false;
      expect(await controller.toggleFullscreen(), false);
    },
  );
  test(
    'only successful combat actions pulse; pause and disposal cancel vibration',
    () {
      final bridge = FakeDevice();
      var time = Duration.zero;
      final settings = DeviceSettings(bridge: bridge, now: () => time);
      addTearDown(settings.dispose);
      final s = Adventure(GameArt(), device: settings);
      s.start(TestGame());
      s.hit(s.mobs.first, 5, const Offset(0, 0));
      expect(bridge.patterns, [
        [12],
      ]);
      s.pause();
      time = const Duration(seconds: 1);
      s.hero.skill();
      s.hit(s.mobs.first, 5, const Offset(0, 0));
      expect(bridge.patterns.length, 1);
      expect(bridge.cancellations, 1);
      s.resume();
      s.hero.skill();
      expect(bridge.patterns.last, [12, 18, 24]);
      time = const Duration(seconds: 2);
      s.hurtHero(5);
      expect(bridge.patterns.last, [32, 22, 45]);
      final count = bridge.patterns.length;
      s.hurtHero(5);
      expect(bridge.patterns.length, count);
      s.dispose();
      expect(bridge.cancellations, 2);
      s.hero.skill();
      expect(bridge.patterns.length, count);
    },
  );
  test('a failing vibration device never interrupts combat', () {
    final bridge = FakeDevice()..failVibration = true;
    final settings = DeviceSettings(bridge: bridge);
    addTearDown(settings.dispose);
    final s = Adventure(GameArt(), device: settings);
    s.start(TestGame());
    addTearDown(s.dispose);
    s.hit(s.mobs.first, 99999, const Offset(0, 0));
    expect(s.progress.kills, 1);
  });
}
