import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keeps the user's complete painting intact, including in portrait viewports.
/// The opaque action panel replaces the painting's decorative PRESS START.
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff111b18),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = math.min(box.maxWidth / 1672, box.maxHeight / 941);
          final imageHeight = 941 * scale;
          final imageTop = (box.maxHeight - imageHeight) / 2;
          final panelWidth = math.min(
            math.max(164.0, 1672 * scale * .20),
            box.maxWidth - 32,
          );
          final top = imageTop + imageHeight * .50;
          return Stack(
            fit: StackFit.expand,
            children: [
              Semantics(
                label: '자연의 수호자 · Guardians of Nature',
                image: true,
                child: Image.asset(
                  'assets/images/guardian-title.png',
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
              Positioned(
                left: (box.maxWidth - panelWidth) / 2,
                top: math.min(top, math.max(0, box.maxHeight - 180)),
                width: panelWidth,
                bottom: 0,
                child: SingleChildScrollView(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xff15231e),
                      border: Border.all(color: const Color(0xffbbaa76)),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 20),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton(
                            key: const ValueKey('title-start'),
                            onPressed: onStart,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              backgroundColor: const Color(0xffd5c18c),
                              foregroundColor: const Color(0xff15231e),
                            ),
                            child: const Text('시작'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            key: const ValueKey('title-continue'),
                            onPressed: onContinue,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            child: const Text('이어하기'),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            continueSummary ?? '저장된 모험이 없습니다',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xffe4dcc6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
