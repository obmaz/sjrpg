import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'entry_art_widgets.dart';
import 'game_art.dart';
import 'rpg_model.dart';

class ClassSelection extends StatefulWidget {
  const ClassSelection({
    required this.art,
    required this.onBegin,
    this.onContinue,
    this.onBack,
    this.showContinue = true,
    this.continueSummary,
    super.key,
  });
  final GameArt art;
  final ValueChanged<HeroClass> onBegin;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;
  final bool showContinue;
  final String? continueSummary;
  @override
  State<ClassSelection> createState() => _ClassSelectionState();
}

class _ClassSelectionState extends State<ClassSelection> {
  HeroClass selected = HeroClass.warrior;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        RawImage(image: widget.art.images['entry-scene'], fit: BoxFit.cover),
        const ColoredBox(color: Color(0xa610211f)),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final compact = box.maxHeight < 600;
              final tightContinue =
                  compact && box.maxWidth >= 600 && widget.showContinue;
              final brandHeight = tightContinue
                  ? 70.0
                  : compact
                  ? 78.0
                  : 111.0;
              final actionHeight = tightContinue
                  ? 50.0
                  : compact
                  ? 54.0
                  : 68.0;
              final continueHeight = !widget.showContinue
                  ? 0.0
                  : tightContinue
                  ? 72.0
                  : 80.0;
              final contentWidth = math.min(530.0, box.maxWidth - 24);
              final cardWidth = (contentWidth - 10) / 2;
              final portraits = widget.art.images['class-selection'];
              final portraitAspect = portraits == null
                  ? .75
                  : portraits.width / 2 / portraits.height;
              final sideName = compact && cardWidth >= 200;
              final portraitWidth = cardWidth * (sideName ? .46 : 1) - 16;
              // Match the painted face and weapon composition while leaving
              // breathing room around the controls.
              final preferredCardHeight = portraitWidth / portraitAspect + 16;
              final cardHeight = math.max(
                112.0,
                math.min(
                  preferredCardHeight,
                  box.maxHeight -
                      (widget.onBack == null ? 0 : 48) -
                      24 -
                      brandHeight -
                      actionHeight -
                      continueHeight -
                      12,
                ),
              );
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(0, box.maxHeight - 24),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 530),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.onBack != null)
                            TextButton.icon(
                              onPressed: widget.onBack,
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('타이틀로 돌아가기'),
                            ),
                          SizedBox(
                            height: brandHeight,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: compact ? 43 : 65,
                                  height: compact ? 52 : 78,
                                  child: CustomPaint(
                                    painter: EntryChrome(
                                      widget.art,
                                      EntryPiece.crest,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '자연의 수호자',
                                        style: TextStyle(
                                          color: entryCream,
                                          fontSize: tightContinue
                                              ? 22
                                              : compact
                                              ? 24
                                              : 29,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        '제1장 · 십자로의 숲',
                                        style: TextStyle(
                                          color: entryBrass,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.showContinue)
                            SizedBox(
                              height: continueHeight,
                              child: Column(
                                children: [
                                  EntryAction(
                                    '모험 이어하기',
                                    art: widget.art,
                                    onTap: widget.onContinue,
                                    height: 47,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    widget.continueSummary ?? '저장된 모험이 없습니다',
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    style: const TextStyle(
                                      color: entryCream,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: cardHeight,
                            child: Row(
                              children: [
                                Expanded(child: _card(HeroClass.warrior)),
                                const SizedBox(width: 10),
                                Expanded(child: _card(HeroClass.mage)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          EntryAction(
                            widget.onContinue != null
                                ? '${selected.title}로 새 모험'
                                : '${selected.title}로 모험 시작',
                            art: widget.art,
                            height: actionHeight,
                            onTap: () => widget.onBegin(selected),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _card(HeroClass heroClass) {
    final active = selected == heroClass;
    void choose() => setState(() => selected = heroClass);
    return Semantics(
      button: true,
      selected: active,
      label: '${heroClass.title} 선택',
      excludeSemantics: true,
      onTap: choose,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: choose,
          child: LayoutBuilder(
            builder: (context, box) {
              final wide =
                  box.maxWidth >= 200 && box.maxWidth > box.maxHeight * 1.25;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      8,
                      8,
                      wide ? box.maxWidth * .54 : 8,
                      8,
                    ),
                    child: ClipRect(
                      child: Opacity(
                        opacity: active ? 1 : .72,
                        child: CustomPaint(
                          painter: ClassPortrait(widget.art, heroClass),
                        ),
                      ),
                    ),
                  ),
                  CustomPaint(
                    painter: EntryChrome(widget.art, EntryPiece.frame),
                  ),
                  Positioned(
                    left: wide ? box.maxWidth * .45 : 6,
                    right: 6,
                    bottom: wide ? (box.maxHeight - 42) / 2 : 6,
                    child: SizedBox(
                      height: 42,
                      child: CustomPaint(
                        painter: EntryChrome(widget.art, EntryPiece.nameplate),
                        child: Center(
                          child: Text(
                            heroClass.title,
                            style: TextStyle(
                              color: active ? entryCream : entryBrass,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (active)
                    Positioned(
                      top: 7,
                      right: 7,
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CustomPaint(
                          painter: EntryChrome(widget.art, EntryPiece.selected),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One shared decoded painting supplies both independently tappable class cards.
class ClassPortrait extends CustomPainter {
  ClassPortrait(this.art, this.heroClass);
  final GameArt art;
  final HeroClass heroClass;
  @override
  void paint(Canvas canvas, Size size) {
    final image = art.images['class-selection'];
    if (image == null) return;
    final half = image.width / 2;
    final source = Rect.fromLTWH(
      heroClass == HeroClass.warrior ? 0 : half,
      0,
      half,
      image.height.toDouble(),
    );
    final fitted = applyBoxFit(BoxFit.cover, source.size, size);
    canvas.drawImageRect(
      image,
      Alignment.topCenter.inscribe(fitted.source, source),
      Alignment.center.inscribe(fitted.destination, Offset.zero & size),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant ClassPortrait oldDelegate) =>
      oldDelegate.heroClass != heroClass || oldDelegate.art != art;
}
