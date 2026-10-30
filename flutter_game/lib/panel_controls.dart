import 'package:flutter/material.dart';
import 'game_ui.dart';

const _muted = Color(0xffa7bac3);

BoxDecoration gameButtonDecoration({
  bool enabled = true,
  bool primary = false,
  double radius = 12,
}) => BoxDecoration(
  color: !enabled ? const Color(0xff1a292c) : null,
  gradient: enabled
      ? LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: primary
              ? const [Color(0xff345b58), Color(0xff183c3e)]
              : const [Color(0xff284b4b), Color(0xff132e34)],
        )
      : null,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(
    color: !enabled
        ? const Color(0xff46564f)
        : primary
        ? gameMetal
        : gameMetal.withValues(alpha: .72),
    width: primary ? 1.5 : 1.1,
  ),
  boxShadow: enabled
      ? const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 2,
            offset: Offset(0, 2),
          ),
        ]
      : null,
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
        dimension: size < 44 ? 44 : size,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: gameButtonDecoration(enabled: onTap != null),
            child: InkWell(
              onTap: onTap,
              splashColor: mobileAccent.withValues(alpha: .12),
              highlightColor: mobileAccent.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(12),
              child: Icon(
                icon,
                size: 20,
                color: onTap == null ? _muted : mobileText,
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
                    color: mobileText,
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
    this.leading,
    this.semanticValue,
    this.semanticLabel,
    this.fontSize = 16,
    this.minHeight = 50,
    super.key,
  });
  final String label;
  final String? semanticLabel;
  final String? semanticValue;
  final Widget? leading;
  final double fontSize;
  final double minHeight;
  final VoidCallback? onTap;
  final bool primary;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      value: semanticValue,
      onTap: onTap,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight < 44 ? 44 : minHeight),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: gameButtonDecoration(
              enabled: enabled,
              primary: primary,
            ),
            child: InkWell(
              customBorder: shape,
              onTap: onTap,
              splashColor: mobileAccent.withValues(alpha: .12),
              highlightColor: mobileAccent.withValues(alpha: .06),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 6),
                    ],
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 17,
                        color: enabled ? mobileText : _muted,
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
                          color: enabled ? mobileText : _muted,
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
  const GameTabs(
    this.labels,
    this.selected,
    this.onChange, {
    this.flat = false,
    super.key,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChange;
  final bool flat;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      alignment: Alignment.center,
                      decoration: flat
                          ? null
                          : gameButtonDecoration(primary: selected == i),
                      foregroundDecoration: flat
                          ? BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: selected == i
                                      ? mobileAccent
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            )
                          : null,
                      child: Ink(
                        decoration: flat
                            ? BoxDecoration(
                                color: selected == i
                                    ? mobileAccent.withValues(alpha: .10)
                                    : Colors.transparent,
                              )
                            : null,
                        child: Text(
                          labels[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: selected == i ? mobileText : _muted,
                            fontWeight: FontWeight.bold,
                          ),
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
    ),
  );
}
