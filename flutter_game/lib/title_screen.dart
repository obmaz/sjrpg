import 'package:flutter/material.dart';

import 'landscape_entry.dart';

class TitleScreen extends StatelessWidget {
  const TitleScreen({
    required this.onStart,
    this.onContinue,
    this.continueSummary,
    super.key,
  });
  final VoidCallback onStart;
  final VoidCallback? onContinue;
  final String? continueSummary;

  @override
  Widget build(BuildContext context) => LandscapeEntry(
    fill: true,
    builder: (scale) => Stack(
      children: [
        Positioned.fill(
          child: Semantics(
            label: '자연의 수호자 · Guardians of Nature',
            image: true,
            child: entryImage('guardian-title'),
          ),
        ),
        EntryHotspot(
          key: const ValueKey('title-start'),
          rect: const Rect.fromLTWH(620, 455, 432, 112),
          scale: scale,
          label: '시작',
          onTap: onStart,
          artwork: const SizedBox.expand(),
        ),
        EntryHotspot(
          key: const ValueKey('title-continue'),
          rect: const Rect.fromLTWH(696, 590, 280, 72),
          scale: scale,
          label: '이어하기',
          hint: continueSummary ?? '저장된 모험이 없습니다',
          onTap: onContinue,
          artwork: const EntryPlaque('이어하기'),
        ),
        if (continueSummary != null)
          Positioned(
            left: 590,
            top: 688,
            width: 492,
            height: 82,
            child: IgnorePointer(
              child: Text(
                continueSummary!,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 24,
                  color: Color(0xffefe5d1),
                  shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
