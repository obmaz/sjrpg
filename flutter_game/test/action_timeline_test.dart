import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/actor_motion.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/boss_sprite_mesh.dart';
import 'package:guardian_new/game_art.dart';

import 'support/test_game.dart';

class TimelineArt extends GameArt {
  ({bool attacking, double progress, int pose})? heroPose;
  BossVisualPose? bossPose;

  @override
  void actor(
    ui.Canvas canvas,
    String key,
    ui.Offset feet,
    double angle,
    int phase,
    double height, {
    bool attack = false,
    bool moving = false,
    int comboPose = 0,
    double? actionProgress,
    BossVisualPose? bossPose,
    Object? mountPose,
    double opacity = 1,
    double flash = 0,
  }) {
    if (key == 'hero') {
      heroPose = (
        attacking: attack,
        progress: actionProgress ?? 0,
        pose: comboPose,
      );
    }
    if (bossPose != null) this.bossPose = bossPose;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Adventure field(TimelineArt art) {
    final s = inCombatField(Adventure(art))..start(TestGame());
    addTearDown(s.dispose);
    s.waveTime = 10000;
    s.progress
      ..level = 20
      ..skillPoints = 100
      ..energy = 100;
    for (var y = 4000.0; y < 8000; y += 80) {
      if (!s.world.blocked(ui.Rect.fromLTWH(5950, y - 50, 700, 120))) {
        s.hero.position.setValues(6000, y);
        s.hero.lastClearPosition = ui.Offset(
          s.hero.position.x,
          s.hero.position.y,
        );
        break;
      }
    }
    expect(s.sheltered, false);
    return s;
  }

  void learn(Adventure s, String id, {int rank = 1}) {
    final def = s.progress.skills.firstWhere((d) => d.id == id);
    for (final parent in def.requires.entries) {
      learn(s, parent.key, rank: parent.value);
    }
    while (s.progress.rank(id) < rank) {
      expect(s.progress.learn(def), true);
    }
    s.progress.energy = s.progress.maxEnergy;
  }

  void render(void Function(ui.Canvas) paint) {
    final recorder = ui.PictureRecorder();
    paint(ui.Canvas(recorder));
    recorder.endRecording().dispose();
  }

  for (final id in ['warcry', 'frenzy']) {
    test(
      '$id gesture advances through every action frame before basic attack',
      () {
        final art = TimelineArt(), s = field(art);
        learn(s, id);
        expect(s.progress.selectSkill(id), true);
        s.hero.skill();
        expect(s.hero.castLock, greaterThan(0));
        final strikes = s.hero.strikes;
        s.hero.slash();
        expect(s.hero.strikes, strikes);
        final phases = <int>{};
        var steps = 0;
        while (s.hero.swing > 0 && steps++ < 200) {
          render(s.hero.render);
          final pose = art.heroPose!;
          expect(pose.attacking, true);
          expect(pose.pose, 2);
          phases.add((pose.progress * 8).floor().clamp(0, 7));
          final before = s.hero.swing;
          s.hero.update(0);
          expect(s.hero.swing, before);
          s.hero.update(1 / 120);
        }
        expect(steps, lessThan(200));
        expect(phases, {0, 1, 2, 3, 4, 5, 6, 7});
        s.hero.slash();
        expect(s.hero.strikes, strikes + 1);
      },
    );
  }

  test('actual charge ends without rewinding into a middle attack pose', () {
    final art = TimelineArt(), s = field(art);
    learn(s, 'charge');
    expect(s.progress.selectSkill('charge'), true);
    s.hero.bearing = 0;
    s.hero.skill();
    var previous = -1.0, frames = 0;
    while (s.hero.chargeTime > 0 && frames++ < 100) {
      render(s.hero.render);
      final pose = art.heroPose!;
      expect(pose.attacking, true);
      expect(pose.pose, 1);
      expect(pose.progress, greaterThanOrEqualTo(previous));
      previous = pose.progress;
      s.hero.update(1 / 120);
    }
    expect(frames, lessThan(100));
    expect(previous, greaterThan(.9));
    render(s.hero.render);
    expect(art.heroPose!.attacking, false);
    expect(s.hero.swing, 0);
  });

  test('whirlwind cannot reveal an older basic swing on completion', () {
    final art = TimelineArt(), s = field(art);
    learn(s, 'whirlwind');
    expect(s.progress.selectSkill('whirlwind'), true);
    s.hero.slash();
    expect(s.hero.swing, greaterThan(0));
    s.hero.skill();
    expect(s.hero.spin, greaterThan(0));
    expect(s.hero.swing, 0);
    for (var i = 0; i < 100 && s.hero.spin > 0; i++) {
      s.hero.update(1 / 120);
    }
    expect(s.hero.spin, 0);
    render(s.hero.render);
    expect(art.heroPose!.attacking, false);
  });

  test('boss windup carries continuously into its first strike frame', () {
    final art = TimelineArt(), s = field(art);
    final boss = s.spawnEnemy(
      'golem',
      s.hero.body.topLeft + const ui.Offset(200, 0),
      boss: true,
    )!;
    boss.meleeWindup = .000001;
    render(boss.render);
    final before = art.bossPose!.windup;
    boss.meleeWindup = 0;
    boss.attackMotion.strike(EnemyAttackPose.slam, 0);
    render(boss.render);
    expect(art.bossPose!.windup, closeTo(before, .00001));
    expect(art.bossPose!.strike, 0);
    boss.attackMotion.update(EnemyAttackMotion.recovery * .25);
    render(boss.render);
    expect(art.bossPose!.windup, closeTo(0, .000001));
    expect(art.bossPose!.strike, closeTo(1, .000001));
  });
}
