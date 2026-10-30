import 'package:flutter/material.dart';
import 'game_ui.dart';
import 'panel_controls.dart';

class GameSettingToggle extends StatelessWidget {
  const GameSettingToggle({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.icon,
    super.key,
  });
  final String label, subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final accent = enabled && value ? gold : const Color(0xff829c92);
    void toggle() => onChanged?.call(!value);
    return Semantics(
      container: true,
      label: label,
      hint: subtitle,
      toggled: value,
      enabled: enabled,
      onTap: enabled ? toggle : null,
      excludeSemantics: true,
      child: Material(
        color: const Color(0xff122e2a),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: accent.withValues(alpha: .45)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? toggle : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: accent, size: 23),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: cream,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xffbacdbe),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 54,
                  height: 30,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: value && enabled
                        ? const Color(0xff4f542e)
                        : const Color(0xff0a201f),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: accent.withValues(alpha: .7)),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 140),
                    alignment: value
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: value && enabled
                              ? [
                                  const Color(0xfff2daa0),
                                  const Color(0xffae8043),
                                ]
                              : [
                                  const Color(0xffa5bbb0),
                                  const Color(0xff5c7a6d),
                                ],
                        ),
                      ),
                      child: value
                          ? const Icon(Icons.check, size: 15, color: ink)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GameNoticeDialog extends StatelessWidget {
  const GameNoticeDialog({
    required this.title,
    required this.message,
    required this.icon,
    super.key,
  });
  final String title, message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 420,
        maxHeight:
            MediaQuery.sizeOf(context).height -
            MediaQuery.viewInsetsOf(context).vertical -
            48,
      ),
      child: Material(
        textStyle: DefaultTextStyle.of(context).style,
        color: const Color(0xff102d2a),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xff577d72)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GamePanelHeader(
              title: title,
              trailing: Icon(icon, color: gold),
              onClose: () => Navigator.pop(context),
            ),
            const Divider(height: 1, color: Color(0xff3b584c)),
            Flexible(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Text(
                  message,
                  style: const TextStyle(
                    color: cream,
                    fontSize: 16,
                    height: 1.7,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GameAction(
                '확인',
                primary: true,
                onTap: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
