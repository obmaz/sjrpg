import 'package:flutter/material.dart';
import 'game_art.dart';
import 'game_ui.dart';
import 'stage_content.dart';

const _muted = Color(0xffb9cec1);

class QuestProgressCard extends StatelessWidget {
  const QuestProgressCard({
    required this.title,
    required this.status,
    required this.progress,
    this.description,
    super.key,
  });
  final String title, status;
  final String? description;
  final double progress;
  @override
  Widget build(BuildContext context) => _QuestSurface(
    done: progress >= 1,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: cream,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (progress >= 1)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xff8bdcc2),
                size: 20,
              ),
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: 8),
          Text(
            description!,
            style: const TextStyle(color: _muted, fontSize: 14, height: 1.5),
          ),
        ],
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          color: gold,
          backgroundColor: const Color(0xff081f1d),
          minHeight: 4,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 8),
        Text(
          status,
          style: const TextStyle(color: gold, fontSize: 13, height: 1.5),
        ),
      ],
    ),
  );
}

class QuestSiteCard extends StatelessWidget {
  const QuestSiteCard({
    required this.art,
    required this.site,
    required this.done,
    required this.stage,
    super.key,
  });
  final GameArt art;
  final QuestSite site;
  final bool done;
  final WorldStage stage;
  @override
  Widget build(BuildContext context) => _QuestSurface(
    done: done,
    child: Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: site.color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ExcludeSemantics(
            child: CustomPaint(painter: _SiteArt(art, site.artIndex, stage)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                site.name,
                style: const TextStyle(
                  color: cream,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                done
                    ? (stage == WorldStage.forest ? '정화 완료' : '복구 완료')
                    : site.hint,
                style: TextStyle(
                  color: done ? const Color(0xff8bdcc2) : _muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        if (done)
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xff8bdcc2),
            size: 20,
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: gold.withValues(alpha: .45)),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              '필수',
              style: TextStyle(color: gold, fontSize: 12),
            ),
          ),
      ],
    ),
  );
}

class _QuestSurface extends StatelessWidget {
  const _QuestSurface({required this.child, required this.done});
  final Widget child;
  final bool done;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: done ? const Color(0xff16392f) : const Color(0xff102d29),
      border: Border.all(
        color: done ? const Color(0xff56846a) : const Color(0xff37554b),
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}

class _SiteArt extends CustomPainter {
  _SiteArt(this.art, this.index, this.stage);
  final GameArt art;
  final int index;
  final WorldStage stage;
  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide - 4;
    final feet = Offset(
      size.width / 2,
      (size.height - side) / 2 + side * .9375,
    );
    if (stage.usesCityArt) {
      art.cityProp(canvas, index, feet, side);
    } else {
      art.landmark(
        canvas,
        index,
        feet,
        side,
        themed: stage != WorldStage.forest,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SiteArt oldDelegate) =>
      oldDelegate.art != art ||
      oldDelegate.index != index ||
      oldDelegate.stage != stage;
}
