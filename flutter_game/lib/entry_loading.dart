import 'package:flutter/material.dart';

import 'entry_art_widgets.dart';
import 'game_art.dart';
import 'game_ui.dart';
import 'landscape_entry.dart';

/// Neutral loading surface shared with the web bootstrap.
class EntryLoading extends StatelessWidget {
  const EntryLoading({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        const EntryBackdrop(),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x99081715), Color(0x15081715), Color(0xf5091715)],
              stops: [0, .48, 1],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                const EntryCrest(),
                const SizedBox(height: 10),
                const Text(
                  '자연의 수호자',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cream,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    shadows: [Shadow(color: Colors.black, blurRadius: 18)],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '숲이 당신을 기다립니다',
                  style: TextStyle(
                    color: entryBrass,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(flex: 3),
                const EntryProgress(),
                const SizedBox(height: 16),
                const Text(
                  '모험의 풍경을 불러오고 있어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cream, fontSize: 14),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// One upright landscape for bootstrap, startup and session preparation.
class EntryBackdrop extends StatelessWidget {
  const EntryBackdrop({this.art, super.key});
  final GameArt? art;
  @override
  Widget build(BuildContext context) {
    final image = art?.images['entry-scene'];
    return ExcludeSemantics(
      child: ColoredBox(
        color: ink,
        child: image != null
            ? RawImage(image: image, fit: BoxFit.cover)
            : Image.asset(
                'assets/images/entry-scene.webp',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.expand(),
              ),
      ),
    );
  }
}

/// Session preparation shares the title's landscape canvas, including its panel.
class LandscapePreparation extends StatelessWidget {
  const LandscapePreparation({required this.art, super.key});
  final GameArt art;
  @override
  Widget build(BuildContext context) => LandscapeEntry(
    fill: true,
    builder: (scale) => Stack(
      fit: StackFit.expand,
      children: [
        EntryBackdrop(art: art),
        const ColoredBox(color: Color(0xbb071d1c)),
        Center(
          child: Transform.scale(
            scale: 1 / scale,
            child: EntryPreparationPanel(art: art),
          ),
        ),
      ],
    ),
  );
}

/// Prepared sessions use their retained atlas rather than issuing asset reads.
class EntryCrest extends StatelessWidget {
  const EntryCrest({this.art, this.height = 66, super.key});
  final GameArt? art;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: height * 58 / 66,
    height: height,
    child: art == null
        ? Image.asset(
            'assets/images/entry-crest.webp',
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          )
        : art!.images.containsKey('entry-ui')
        ? CustomPaint(painter: EntryChrome(art!, EntryPiece.crest))
        : const Icon(Icons.eco_outlined, color: entryBrass),
  );
}

class EntryProgress extends StatelessWidget {
  const EntryProgress({this.art, super.key});
  final GameArt? art;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 240,
    height: 32,
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (art == null)
          Image.asset(
            'assets/images/entry-loading-bar.webp',
            fit: BoxFit.fill,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          )
        else if (art!.images.containsKey('entry-ui'))
          CustomPaint(painter: EntryChrome(art!, EntryPiece.progress))
        else
          const Center(child: Divider(color: entryBrass)),
        const Positioned(
          left: 21,
          right: 21,
          top: 14,
          child: LinearProgressIndicator(
            color: entryBrass,
            backgroundColor: Color(0xff172a27),
            minHeight: 3,
            semanticsLabel: '모험 준비 중',
          ),
        ),
      ],
    ),
  );
}

class EntryPreparationPanel extends StatelessWidget {
  const EntryPreparationPanel({required this.art, super.key});
  final GameArt art;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: '모험 준비 중',
    excludeSemantics: true,
    child: Material(
      type: MaterialType.transparency,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 290),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xf2182925),
            border: Border.all(color: entryBrass),
          ),
          child: CustomPaint(
            painter: EntryChrome(art, EntryPiece.nameplate),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EntryCrest(art: art, height: 46),
                  const SizedBox(height: 10),
                  const Text(
                    '모험 준비 중',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Guardian',
                      color: entryCream,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  EntryProgress(art: art),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
