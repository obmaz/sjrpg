import 'dart:async' as async;
import 'dart:math' as math;
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
import 'panel_controls.dart';
import 'game_checkpoint.dart';
import 'save_bridge.dart' as storage;

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
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
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
  GameCheckpoint? savedAdventure = GameCheckpoint.decode(
    storage.readCheckpoint(),
  );
  bool resuming = false, enteringStage = false;
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
                  GameAction(
                    '다시 불러오기',
                    primary: true,
                    icon: Icons.refresh,
                    onTap: () => setState(() => loading = GameArt.load()),
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
          showStageBriefing: enteringStage,
          checkpoint: resuming ? savedAdventure : null,
          onAdvance: (checkpoint) => setState(() {
            run++;
            savedAdventure = checkpoint;
            enteringStage = true;
            resuming = true;
            started = true;
          }),
          onRetryCheckpoint: () {
            final checkpoint = GameCheckpoint.decode(storage.readCheckpoint());
            setState(() {
              run++;
              savedAdventure = checkpoint;
              enteringStage = false;
              resuming = checkpoint != null;
              started = checkpoint != null;
              if (checkpoint != null) chosen = checkpoint.progress.heroClass;
            });
          },
          onRestart: () => setState(() {
            run++;
            started = false;
            savedAdventure = null;
            resuming = false;
            enteringStage = false;
          }),
        );
      }
      return ClassSelection(
        art: art,
        continueSummary: savedAdventure?.summary,
        onContinue: savedAdventure == null
            ? null
            : () => setState(() {
                chosen = savedAdventure!.progress.heroClass;
                resuming = true;
                enteringStage = false;
                started = true;
              }),
        onBegin: (value) => setState(() {
          chosen = value;
          resuming = false;
          enteringStage = false;
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
    this.checkpoint,
    this.showStageBriefing = false,
    this.onRetryCheckpoint,
    this.onAdvance,
    super.key,
  });
  final GameCheckpoint? checkpoint;
  final bool showStageBriefing;
  final HeroClass heroClass;
  final GameArt art;
  final VoidCallback onRestart;
  final VoidCallback? onRetryCheckpoint;
  final ValueChanged<GameCheckpoint>? onAdvance;
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with WidgetsBindingObserver {
  late final Adventure adventure =
      widget.checkpoint?.restore(widget.art) ??
      Adventure(widget.art, heroClass: widget.heroClass);
  async.Timer? saveTimer;
  void Function()? stopSaveListener;
  bool keepSave = true;
  void saveNow() {
    if (!keepSave) return;
    final checkpoint = GameCheckpoint.capture(adventure);
    if (checkpoint != null) storage.writeCheckpoint(checkpoint.encode());
  }

  void advanceStage() {
    final next = GameCheckpoint.advance(adventure);
    if (next == null || widget.onAdvance == null) return;
    keepSave = false;
    storage.writeCheckpoint(next.encode());
    widget.onAdvance!(next);
  }

  void abandon() {
    keepSave = false;
    storage.clearCheckpoint();
    widget.onRestart();
  }

  late final Widget game;
  String? panel;
  final gameFocus = FocusNode();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    saveTimer = async.Timer.periodic(
      const Duration(seconds: 5),
      (_) => saveNow(),
    );
    stopSaveListener = storage.listenForExit(saveNow);
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
        initPosition: Vector2(
          adventure.world.spawn.dx + 12,
          adventure.world.spawn.dy + 11,
        ),
        startFollowPlayer: false,
        movementWindow: Vector2.zero(),
        zoom: 1,
      ),
      collisionConfig: BonfireCollisionConfig.quadTree(),
      backgroundColor: ink,
      focusNode: gameFocus,
      onReady: (game) {
        game.camera.updateBoundsAndZoomFit(moveOnlyMapArea: true);
        game.camera.position = adventure.cameraFocus;
        adventure.start(game);
        saveNow();
        if (widget.showStageBriefing ||
            adventure.world.stage == WorldStage.sands &&
                adventure.timePath == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) open('journal');
          });
        }
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    adventure.viewportSize = size;
    adventure.cameraOffsetY = size.width < 400 && size.height < 520 ? 36 : 0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && adventure.ready && mounted) {
      saveNow();
      open('pause');
    }
  }

  void open(String name) {
    saveNow();
    adventure.pause();
    setState(() => panel = name);
  }

  void close() {
    saveNow();
    setState(() => panel = null);
    adventure.resume();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && panel == null && !adventure.defeated && !adventure.won) {
        gameFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    saveTimer?.cancel();
    stopSaveListener?.call();
    saveNow();
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
        final stick = short && width < 400
                ? 102.0
                : width < 360
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
        final p = adventure.progress, interaction = adventure.nearbyAction;
        final layouts = short && width < 360
            ? [
                (18.0, 156.0, 52.0),
                (66.0, 200.0, 48.0),
                (96.0, 156.0, 48.0),
                (120.0, 102.0, 48.0),
              ]
            : short
            ? [
                (18.0, 132.0, 60.0),
                (90.0, 142.0, 52.0),
                (154.0, 114.0, 52.0),
                (206.0, 66.0, 48.0),
              ]
            : width < 360
            ? [
                (18.0, 152.0, 56.0),
                (66.0, 204.0, 48.0),
                (96.0, 166.0, 48.0),
                (120.0, 112.0, 48.0),
              ]
            : [
                (18.0, 152.0, 64.0),
                (84.0, 192.0, 56.0),
                (148.0, 166.0, 52.0),
                (160.0, 112.0, 48.0),
              ];
        Widget skillButton(int slot) {
          final skill = p.skillAt(slot)!, layout = layouts[slot];
          final remaining = adventure.hero.cooldowns[skill.id] ?? 0;
          final aimed = const {
            'meteor',
            'seismicSlam',
            'charge',
            'crushingBlow',
          }.contains(skill.id);
          return Positioned(
            right: layout.$1,
            bottom: bottom + layout.$2,
            child: ActionButton(
              art: widget.art,
              sprite: 'roundEmpty',
              effect: skillEffect(skill.id),
              showLabel: false,
              label: skill.shortName,
              semanticLabel: slot == 0
                  ? skill.name
                  : slot == 1
                  ? '보조 ${skill.name}'
                  : '스킬 ${slot + 1} ${skill.name}',
              size: layout.$3,
              remaining: remaining,
              total: p.skillCooldown(skill),
              onTap: () => adventure.hero.skill(slot: slot),
              onAimStart: aimed ? () => adventure.hero.beginAim(slot) : null,
              onAimMove: aimed ? adventure.hero.moveAim : null,
              onAimEnd: aimed ? adventure.hero.finishAim : null,
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              excluding: modal != null,
              child: ExcludeFocus(
                excluding: modal != null,
                child: IgnorePointer(ignoring: modal != null, child: child!),
              ),
            ),
            SafeArea(
              bottom: false,
              child: ExcludeSemantics(
                excluding: modal != null,
                child: IgnorePointer(
                  ignoring: modal != null,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: GameHud(
                      adventure,
                      onMap: modal == null ? () => open('map') : null,
                    ),
                  ),
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
                  sprite: 'roundEmpty',
                  artwork: CustomPaint(
                    size: Size.square(attack * .75),
                    painter: GearGlyph(p.weapon, widget.art),
                  ),
                  label: '공격',
                  semanticLabel: '공격',
                  size: attack,
                  remaining: adventure.hero.attackClock,
                  total: p.attackInterval,
                  onHold: (held) => adventure.holdAttack('touch', held),
                  onTap: adventure.hero.slash,
                ),
              ),
              for (var slot = 0; slot < 4; slot++)
                if (p.skillAt(slot) != null) skillButton(slot),
              Positioned(
                right: width < 360 ? 112 : 134,
                bottom: bottom + 20,
                child: ActionButton(
                  art: widget.art,
                  sprite: 'roundEmpty',
                  artwork: CustomPaint(
                    size: Size.square((width < 360 ? 56 : 64) * .78),
                    painter: AbilityPicturePainter(widget.art, 'dodge-icon'),
                  ),
                  label: '회피',
                  semanticLabel: '회피',
                  size: width < 360 ? 56 : 64,
                  remaining: adventure.hero.dodgeClock,
                  total: 1.5,
                  onTap: adventure.hero.dodge,
                ),
              ),
              if (interaction != null)
                Positioned(
                  left: short && width > 500 ? 148 : 12,
                  bottom: bottom + stick + 12,
                  width: 120,
                  child: GameAction(
                    switch (interaction) {
                      NearbyAction.shrine =>
                        adventure.world.stage == WorldStage.sands ? '조사' : '정화',
                      NearbyAction.mount => '타기',
                      NearbyAction.dismount => '내리기',
                      NearbyAction.shop => '상점',
                      NearbyAction.talk => '대화',
                      NearbyAction.chest => '상자 열기',
                    },
                    icon: switch (interaction) {
                      NearbyAction.shrine => Icons.water_drop_outlined,
                      NearbyAction.mount => Icons.pets_outlined,
                      NearbyAction.dismount => Icons.south_west,
                      NearbyAction.shop => Icons.storefront,
                      NearbyAction.talk => Icons.chat_bubble_outline,
                      NearbyAction.chest => Icons.inventory_2_outlined,
                    },
                    onTap: () {
                      switch (interaction) {
                        case NearbyAction.mount:
                          if (adventure.boardNearbyMount()) saveNow();
                        case NearbyAction.dismount:
                          if (adventure.dismount()) saveNow();
                        case NearbyAction.shrine:
                          if (adventure.cleanseNearbySite()) saveNow();
                        case NearbyAction.shop:
                          open('shop');
                        case NearbyAction.talk:
                          open('talk');
                        case NearbyAction.chest:
                          adventure.openChest();
                          gameFocus.requestFocus();
                      }
                    },
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
                  onRestart: abandon,
                  onCheckpoint: saveNow,
                  onAdvance: widget.onAdvance == null ? null : advanceStage,
                  onRetryCheckpoint:
                      adventure.defeated &&
                          widget.onRetryCheckpoint != null &&
                          GameCheckpoint.decode(storage.readCheckpoint()) !=
                              null
                      ? widget.onRetryCheckpoint
                      : null,
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
    badge: target == 'skills'
        ? adventure.progress.skillPoints
        : target == 'journal'
        ? (adventure.world.stage == WorldStage.sands
              ? (4 -
                    adventure.cleansedSites.length +
                    (adventure.progress.bossDefeated ? 0 : 1))
              : (adventure.world.sites.length -
                    adventure.cleansedSites.length +
                    (adventure.progress.bossDefeated ? 0 : 1)))
        : target == 'bag'
        ? adventure.progress.unseenGear.length
        : 0,
    onTap: () => open(target),
  );
}
