import 'package:flutter/material.dart';
import 'game_ui.dart';
import 'interface_art.dart';

const _muted = Color(0xffa4bcb6);

DecorationImage gameButtonImage({bool enabled = true, bool primary = false}) =>
    DecorationImage(
      image: buttonArtwork(enabled: enabled, primary: primary),
      centerSlice: const Rect.fromLTRB(12, 10, 244, 32.6666667),
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
    );

class GameIconButton extends StatelessWidget {
  const GameIconButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.size = 44,
    super.key,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    enabled: onTap != null,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              image: gameButtonImage(enabled: onTap != null),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(7),
              child: Icon(
                icon,
                size: 20,
                color: onTap == null ? _muted : cream,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class GamePanelHeader extends StatelessWidget {
  const GamePanelHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    this.onClose,
    this.closeLabel = '닫기',
    this.dense = false,
    super.key,
  });
  final String title, closeLabel;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onClose;
  final bool dense;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(12, dense ? 4 : 10, 12, dense ? 4 : 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: TextStyle(
                    color: cream,
                    fontSize: dense ? 18 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        if (onClose != null) ...[
          const SizedBox(width: 8),
          GameIconButton(
            label: closeLabel,
            icon: Icons.close_rounded,
            onTap: onClose,
          ),
        ],
      ],
    ),
  );
}

class GameAction extends StatelessWidget {
  const GameAction(
    this.label, {
    required this.onTap,
    this.primary = false,
    this.icon,
    this.semanticLabel,
    this.fontSize = 16,
    super.key,
  });
  final String label;
  final String? semanticLabel;
  final double fontSize;
  final VoidCallback? onTap;
  final bool primary;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final shape = BeveledRectangleBorder(
      borderRadius: BorderRadius.circular(7),
      side: BorderSide(
        color: enabled
            ? (primary ? gold : const Color(0xff608b7c))
            : const Color(0xff37524c),
      ),
    );
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      onTap: onTap,
      excludeSemantics: true,
      child: SizedBox(
        height: 50,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              image: gameButtonImage(enabled: enabled, primary: primary),
            ),
            child: InkWell(
              customBorder: shape,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 17,
                        color: primary && enabled
                            ? ink
                            : enabled
                            ? cream
                            : _muted,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          color: !enabled
                              ? _muted
                              : primary
                              ? ink
                              : cream,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GameTabs extends StatelessWidget {
  const GameTabs(this.labels, this.selected, this.onChange, {super.key});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChange;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              button: true,
              selected: selected == i,
              label: labels[i],
              excludeSemantics: true,
              onTap: () => onChange(i),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onChange(i),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      image: gameButtonImage(primary: selected == i),
                    ),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 14,
                        color: selected == i ? const Color(0xff18342e) : _muted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
