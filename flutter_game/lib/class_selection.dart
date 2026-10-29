import 'package:flutter/material.dart';

import 'game_art.dart';
import 'landscape_entry.dart';
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
  final VoidCallback? onContinue, onBack;
  final bool showContinue;
  final String? continueSummary;
  @override
  State<ClassSelection> createState() => _ClassSelectionState();
}

class _ClassSelectionState extends State<ClassSelection> {
  HeroClass selected = HeroClass.warrior;
  static const warriorCard = Rect.fromLTWH(298, 633, 143, 175);
  static const mageCard = Rect.fromLTWH(463, 634, 139, 172);

  @override
  Widget build(BuildContext context) => LandscapeEntry(
    builder: (scale) => Stack(
      children: [
        Positioned.fill(child: entryImage('select-scene')),
        Positioned(
          left: 18,
          top: 46,
          width: 440,
          height: 198,
          child: entryImage('select-header'),
        ),
        Positioned(
          left: 1165,
          top: 249,
          width: 455,
          height: 457,
          child: Semantics(
            label: selected == HeroClass.warrior
                ? '전사 · 근접 전투 · 전열에서 적을 막고 무기와 함성으로 싸웁니다'
                : '마법사 · 원거리 전투 · 화염·냉기·번개 주문으로 적을 제압합니다',
            image: true,
            child: entryImage('select-${selected.name}-info'),
          ),
        ),
        for (final hero in HeroClass.values)
          EntryHotspot(
            key: ValueKey('select-${hero.name}'),
            rect: hero == HeroClass.warrior ? warriorCard : mageCard,
            scale: scale,
            label: '${hero.title} 선택',
            selected: selected == hero,
            onTap: () => setState(() => selected = hero),
            artwork: entryImage('select-${hero.name}-card'),
          ),
        Positioned.fromRect(
          rect: (selected == HeroClass.warrior ? warriorCard : mageCard)
              .inflate(6),
          child: IgnorePointer(child: entryImage('select-frame')),
        ),
        EntryHotspot(
          key: const ValueKey('select-start'),
          rect: const Rect.fromLTWH(670, 823, 330, 68),
          scale: scale,
          label: widget.onContinue != null
              ? '${selected.title}로 새 모험'
              : '${selected.title}로 모험 시작',
          onTap: () => widget.onBegin(selected),
          artwork: entryImage('select-start'),
        ),
        if (widget.onBack != null)
          EntryHotspot(
            key: const ValueKey('select-back'),
            rect: const Rect.fromLTWH(41, 835, 149, 55),
            scale: scale,
            label: '타이틀로 돌아가기',
            onTap: widget.onBack,
            artwork: entryImage('select-back'),
          ),
        if (widget.showContinue && widget.onContinue != null)
          EntryHotspot(
            rect: const Rect.fromLTWH(1165, 760, 330, 72),
            scale: scale,
            label: '모험 이어하기',
            hint: widget.continueSummary,
            onTap: widget.onContinue,
            artwork: const EntryPlaque('이어하기'),
          ),
      ],
    ),
  );
}
