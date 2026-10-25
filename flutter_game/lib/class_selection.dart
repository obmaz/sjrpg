import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_art.dart';
import 'game_ui.dart';
import 'rpg_model.dart';

class ClassSelection extends StatefulWidget {
  const ClassSelection({required this.art, required this.onBegin, super.key});
  final GameArt art;
  final ValueChanged<HeroClass> onBegin;
  @override
  State<ClassSelection> createState() => _ClassSelectionState();
}

class _ClassSelectionState extends State<ClassSelection> {
  HeroClass selected = HeroClass.warrior;
  bool get compact => MediaQuery.sizeOf(context).height < 520;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        RawImage(image: widget.art.images['village-scene'], fit: BoxFit.cover),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x550c2423), Color(0xee102f2d), ink],
            ),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: 22,
                vertical: compact ? 12 : 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0, box.maxHeight - (compact ? 24 : 48)),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 510),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!compact)
                          const Text(
                            'GUARDIAN OF NATURE',
                            style: TextStyle(
                              color: gold,
                              fontSize: 11,
                              letterSpacing: 3,
                            ),
                          ),
                        if (!compact) const SizedBox(height: 12),
                        Text(
                          '자연의 수호자',
                          style: TextStyle(
                            fontSize: compact ? 26 : 32,
                            fontWeight: FontWeight.bold,
                            color: cream,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '제1장 · 십자로의 숲',
                          style: TextStyle(color: cream, fontSize: 16),
                        ),
                        SizedBox(height: compact ? 10 : 30),
                        if (!compact)
                          const Text(
                            '어떤 힘으로 어둠에 맞서겠습니까?',
                            style: TextStyle(color: cream, fontSize: 15),
                          ),
                        SizedBox(height: compact ? 10 : 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final c in HeroClass.values)
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: c == HeroClass.warrior ? 6 : 0,
                                    left: c == HeroClass.mage ? 6 : 0,
                                  ),
                                  child: _card(c),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: compact ? 10 : 18),
                        if (!compact)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: ink.withValues(alpha: .88),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: gold.withValues(alpha: .35),
                              ),
                            ),
                            child: Text(
                              selected == HeroClass.warrior
                                  ? '연속 베기로 분노를 모으고 함성으로 적을 제압하세요. 성장하면 소용돌이와 광전사의 격노를 배울 수 있습니다.'
                                  : '화염탄으로 거리를 유지하고 서릿발로 적을 얼리세요. 성장하면 연쇄 번개와 유성을 배울 수 있습니다.',
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.7,
                                color: cream,
                              ),
                            ),
                          ),
                        SizedBox(height: compact ? 10 : 22),
                        SizedBox(
                          width: double.infinity,
                          height: compact ? 48 : 56,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: gold,
                              foregroundColor: ink,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => widget.onBegin(selected),
                            child: Text(
                              '${selected.title}로 모험 시작',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        if (!compact) const SizedBox(height: 14),
                        if (!compact)
                          const Text(
                            '장비를 모으고, 스킬을 키워 첫 파수꾼을 쓰러뜨리세요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xffb5c6b5),
                              fontSize: 12,
                              height: 1.6,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
  Widget _card(HeroClass c) {
    final active = selected == c;
    return Semantics(
      button: true,
      selected: active,
      label: '${c.title} 선택',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => setState(() => selected = c),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.fromLTRB(
            10,
            compact ? 8 : 12,
            10,
            compact ? 10 : 16,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: active
                  ? [const Color(0xff31554b), const Color(0xff122d2d)]
                  : [const Color(0xff203b38), const Color(0xff102825)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? gold : const Color(0xff527268),
              width: active ? 2 : 1,
            ),
            boxShadow: active
                ? [const BoxShadow(color: Color(0x33d5b772), blurRadius: 20)]
                : [],
          ),
          child: Column(
            children: [
              SizedBox(
                height: compact ? 70 : 138,
                width: 140,
                child: CustomPaint(painter: ClassFigure(widget.art, c)),
              ),
              Text(
                c.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: cream,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                c.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: gold),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    active ? Icons.check_circle : Icons.circle_outlined,
                    size: 17,
                    color: active ? gold : const Color(0xff6e8b80),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    active ? '선택됨' : '선택',
                    style: TextStyle(
                      fontSize: 13,
                      color: active ? gold : cream,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ClassFigure extends CustomPainter {
  ClassFigure(this.art, this.heroClass);
  final GameArt art;
  final HeroClass heroClass;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height - 10),
        width: 90,
        height: 24,
      ),
      Paint()..color = const Color(0x66071618),
    );
    art.actor(
      canvas,
      heroClass == HeroClass.mage ? 'mage' : 'hero',
      Offset(size.width / 2, size.height - 8),
      math.pi / 2,
      0,
      size.height - 12,
    );
  }

  @override
  bool shouldRepaint(covariant ClassFigure oldDelegate) =>
      oldDelegate.heroClass != heroClass || oldDelegate.art != art;
}
