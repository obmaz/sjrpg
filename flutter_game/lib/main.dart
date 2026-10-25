import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'adventure.dart';
import 'game_art.dart';
import 'game_ui.dart';
import 'game_panels.dart';
import 'world_model.dart';
import 'class_selection.dart';
import 'battle_effects.dart';
import 'rpg_widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GuardianApp());
}

class GuardianApp extends StatelessWidget {
  const GuardianApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '자연의 수호자',
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Guardian',
      colorScheme: ColorScheme.fromSeed(
        seedColor: gold,
        brightness: Brightness.dark,
        surface: ink,
      ),
      scaffoldBackgroundColor: ink,
    ),
    home: const EntryPage(),
  );
}

class EntryPage extends StatefulWidget {
  const EntryPage({super.key});
  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> {
  late Future<GameArt> loading = GameArt.load();
  bool started = false;
  int run = 0;
  HeroClass chosen = HeroClass.warrior;
  @override
  Widget build(BuildContext context) => FutureBuilder<GameArt>(
    future: loading,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '그림을 불러오지 못했습니다. 연결을 확인하고 다시 시도해 주세요.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => setState(() => loading = GameArt.load()),
                    child: const Text('다시 불러오기'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: gold),
                SizedBox(height: 24),
                Text('모험의 풍경을 불러오고 있어요', style: TextStyle(color: cream)),
              ],
            ),
          ),
        );
      }
      final art = snapshot.data!;
      if (started) {
        return GamePage(
          key: ValueKey(run),
          art: art,
          heroClass: chosen,
          onRestart: () => setState(() {
            run++;
            started = false;
          }),
        );
      }
      return ClassSelection(
        art: art,
        onBegin: (value) => setState(() {
          chosen = value;
          started = true;
        }),
      );
    },
  );
}

class GamePage extends StatefulWidget {
  const GamePage({
    required this.art,
    required this.onRestart,
    this.heroClass = HeroClass.warrior,
    super.key,
  });
  final HeroClass heroClass;
  final GameArt art;
  final VoidCallback onRestart;
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with WidgetsBindingObserver {
  late final Adventure adventure = Adventure(
    widget.art,
    heroClass: widget.heroClass,
  );
  late final Widget game;
  String? panel;
  final gameFocus = FocusNode();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    game = BonfireWidget(
      map: WorldMap.empty(size: Vector2(worldSize.width, worldSize.height)),
      player: adventure.hero,
      playerControllers: [
        Keyboard(
          config: KeyboardConfig(
            directionalKeys: [
              KeyboardDirectionalKeys.wasd(),
              KeyboardDirectionalKeys.arrows(),
            ],
          ),
        ),
      ],
      components: [
        LandscapeLayer(adventure),
        WorldDirector(adventure),
        StageLandmarks(adventure),
        VillagePerson(adventure, true),
        VillagePerson(adventure, false),
      ],
      cameraConfig: CameraConfig(
        moveOnlyMapArea: false,
        initPosition: Vector2(arrival.dx + 12, arrival.dy + 11),
        startFollowPlayer: false,
        movementWindow: Vector2.zero(),
        zoom: 1,
      ),
      collisionConfig: BonfireCollisionConfig.quadTree(),
      backgroundColor: ink,
      focusNode: gameFocus,
      onReady: (game) {
        game.camera.updateBoundsAndZoomFit(moveOnlyMapArea: true);
        adventure.start(game);
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && adventure.ready && mounted) {
      open('pause');
    }
  }

  void open(String name) {
    adventure.pause();
    setState(() => panel = name);
  }

  void close() {
    setState(() => panel = null);
    adventure.resume();
    gameFocus.requestFocus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    adventure.dispose();
    gameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AnimatedBuilder(
      animation: adventure,
      child: game,
      builder: (context, child) {
        final media = MediaQuery.of(context),
            width = media.size.width,
            short = media.size.height < 500;
        final stick = width < 360
                ? 122.0
                : short
                ? 112.0
                : 142.0,
            attack = width < 360 ? 90.0 : 104.0,
            bottom = short ? 86.0 : 112.0;
        final modal = adventure.defeated
            ? 'defeat'
            : adventure.won
            ? 'victory'
            : panel;
        final p = adventure.progress,
            skill = p.activeSkill,
            secondary = p.secondarySkillDef;
        return Stack(
          fit: StackFit.expand,
          children: [
            child!,
            SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: GameHud(
                  adventure,
                  onMap: modal == null ? () => open('map') : null,
                ),
              ),
            ),
            if (!adventure.ready)
              const Center(child: CircularProgressIndicator(color: gold)),
            if (modal == null && adventure.ready) ...[
              Positioned(
                left: 12,
                bottom: bottom,
                child: GameStick(
                  art: widget.art,
                  size: stick,
                  onChange: (angle, intensity) =>
                      adventure.hero.onJoystickChangeDirectional(
                        JoystickDirectionalEvent(
                          directional: intensity == 0
                              ? JoystickMoveDirectional.IDLE
                              : JoystickMoveDirectional.MOVE_RIGHT,
                          radAngle: angle,
                          intensity: intensity,
                        ),
                      ),
                ),
              ),
              Positioned(
                right: width < 360 ? 14 : 22,
                bottom: bottom,
                child: ActionButton(
                  art: widget.art,
                  sprite: p.heroClass == HeroClass.mage
                      ? 'roundEmpty'
                      : 'touchAttack',
                  icon: p.heroClass == HeroClass.mage
                      ? elementIcon(p.weapon.base.style)
                      : null,
                  label: '공격',
                  semanticLabel: '공격',
                  size: attack,
                  remaining: adventure.hero.attackClock,
                  total: p.attackInterval,
                  onHold: (held) => adventure.holdAttack('touch', held),
                  onTap: adventure.hero.slash,
                ),
              ),
              Positioned(
                right: width < 360 ? 24 : 32,
                bottom: bottom + (short ? 108 : 136),
                child: ActionButton(
                  art: widget.art,
                  sprite: 'roundEmpty',
                  effect: skillEffect(skill.id),
                  label: adventure.hero.skillClock > 0
                      ? '${adventure.hero.skillClock.ceil()}초'
                      : skill.shortName,
                  semanticLabel: skill.name,
                  size: short ? 62 : 72,
                  remaining: adventure.hero.skillClock,
                  total: skill.cooldown,
                  onTap: adventure.hero.skill,
                ),
              ),
              if (secondary != null)
                Positioned(
                  right: width < 360 ? 107 : 124,
                  bottom: bottom + (short ? 104 : 130),
                  child: ActionButton(
                    art: widget.art,
                    sprite: 'roundEmpty',
                    effect: skillEffect(secondary.id),
                    label: (adventure.hero.cooldowns[secondary.id] ?? 0) > 0
                        ? '${adventure.hero.cooldowns[secondary.id]!.ceil()}초'
                        : secondary.shortName,
                    semanticLabel: '보조 ${secondary.name}',
                    size: short ? 54 : 60,
                    remaining: adventure.hero.cooldowns[secondary.id] ?? 0,
                    total: secondary.cooldown,
                    onTap: () => adventure.hero.skill(secondary: true),
                  ),
                ),
              Positioned(
                right: width < 360 ? 112 : 134,
                bottom: bottom + 20,
                child: ActionButton(
                  art: widget.art,
                  sprite: 'roundEmpty',
                  icon: Icons.air_rounded,
                  label: '회피',
                  semanticLabel: '회피',
                  size: width < 360 ? 56 : 64,
                  remaining: adventure.hero.dodgeClock,
                  total: 1.5,
                  onTap: adventure.hero.dodge,
                ),
              ),
              if ((adventure.hero.position.toOffset() -
                          const ui.Offset(3952, 2984))
                      .distance <
                  165)
                Positioned(
                  left: 24,
                  bottom: bottom + stick + 12,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: ink.withValues(alpha: .9),
                      foregroundColor: cream,
                      side: const BorderSide(color: gold),
                    ),
                    onPressed: () => open('shop'),
                    icon: const Icon(Icons.storefront, size: 20),
                    label: const Text('상점'),
                  ),
                ),
              if ((adventure.hero.position.toOffset() -
                          const ui.Offset(3660, 2952))
                      .distance <
                  135)
                Positioned(
                  left: 24,
                  bottom: bottom + stick + 12,
                  child: FilledButton.icon(
                    onPressed: () => open('talk'),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('대화'),
                  ),
                ),
              Positioned(
                left: 14,
                top: media.padding.top + 110,
                child: PotionBelt(adventure),
              ),
              if (adventure.noticeTime > 0)
                Positioned(
                  left: 55,
                  right: 55,
                  top: media.padding.top + 160,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: ink.withValues(alpha: .94),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: gold.withValues(alpha: .6)),
                      ),
                      child: Text(
                        adventure.notice,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: cream,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              if (adventure.nearbyChest != null || adventure.nearbyExit != null)
                Positioned(
                  right: 18,
                  bottom: bottom + (short ? 105 : 138) + 93,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: ink,
                      foregroundColor: gold,
                      side: const BorderSide(color: gold),
                    ),
                    onPressed: () {
                      if (adventure.nearbyChest != null) {
                        adventure.openChest();
                      } else {
                        open('exit');
                      }
                    },
                    icon: Icon(
                      adventure.nearbyChest != null
                          ? Icons.inventory_2_outlined
                          : Icons.door_front_door_outlined,
                      size: 20,
                    ),
                    label: Text(
                      adventure.nearbyChest != null ? '상자 열기' : '출구 확인',
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: math.max(8, media.padding.bottom),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _menu('touchInventory', '가방', 'bag'),
                    _menu('touchQuests', '스킬', 'skills'),
                    _menu('touchCompendium', '여정', 'journal'),
                    _menu('touchSettings', '설정', 'settings'),
                  ],
                ),
              ),
            ],
            if (modal != null)
              Positioned.fill(
                child: AdventurePanel(
                  session: adventure,
                  name: modal,
                  onClose: close,
                  onRestart: widget.onRestart,
                ),
              ),
          ],
        );
      },
    ),
  );
  Widget _menu(String sprite, String label, String target) => MenuButton(
    art: widget.art,
    sprite: sprite,
    label: label,
    badge: target == 'skills' ? adventure.progress.skillPoints : 0,
    onTap: () => open(target),
  );
}
