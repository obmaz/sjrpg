import 'package:flutter/material.dart';
import 'game_ui.dart';

const _muted = Color(0xffa4bcb6);

class GameAction extends StatelessWidget {
  const GameAction(
    this.label, {
    required this.onTap,
    this.primary = false,
    this.icon,
    this.semanticLabel,
    super.key,
  });
  final String label;
  final String? semanticLabel;
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
            decoration: ShapeDecoration(
              shape: shape,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: !enabled
                    ? [const Color(0xff203a36), const Color(0xff162d2a)]
                    : primary
                    ? [const Color(0xffe5c881), const Color(0xffac7d3f)]
                    : [const Color(0xff214d45), const Color(0xff102d2a)],
              ),
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
                          fontSize: 15,
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
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < labels.length; i++)
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
                    color: selected == i
                        ? const Color(0xff24483e)
                        : Colors.transparent,
                    border: Border(
                      bottom: BorderSide(
                        color: selected == i ? gold : const Color(0xff35554b),
                        width: selected == i ? 2 : 1,
                      ),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 14,
                      color: selected == i ? gold : _muted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
