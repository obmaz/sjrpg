import 'package:flutter/material.dart';
import 'device_settings.dart';
import 'game_ui.dart';
import 'install_controls.dart';
import 'panel_controls.dart';
import 'settings_controls.dart';

class DeviceControls extends StatefulWidget {
  const DeviceControls(this.settings, {super.key});
  final DeviceSettings settings;
  @override
  State<DeviceControls> createState() => _DeviceControlsState();
}

class _DeviceControlsState extends State<DeviceControls> {
  bool failed = false;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.settings,
    builder: (context, child) {
      final settings = widget.settings;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '화면과 타격감',
            style: TextStyle(
              color: gold,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          GameAction(
            settings.fullscreen ? '전체화면 끄기' : '전체화면 켜기',
            onTap: settings.fullscreenSupported
                ? () async {
                    final success = await settings.toggleFullscreen();
                    if (mounted) setState(() => failed = !success);
                  }
                : null,
            icon: settings.fullscreen
                ? Icons.fullscreen_exit
                : Icons.fullscreen,
          ),
          if (!settings.fullscreenSupported || failed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                failed
                    ? '전체화면으로 전환하지 못했습니다. 브라우저에서 다시 시도해 주세요.'
                    : '이 브라우저에서는 전체화면을 지원하지 않습니다.',
                style: const TextStyle(color: cream, fontSize: 13, height: 1.6),
              ),
            ),
          const SizedBox(height: 12),
          GameSettingToggle(
            label: '타격 진동',
            icon: Icons.vibration,
            subtitle: settings.vibrationSupported
                ? '공격 적중 · 피격 · 스킬 사용'
                : '이 브라우저에서는 진동을 지원하지 않습니다.',
            value: settings.hapticsEnabled,
            onChanged: settings.vibrationSupported ? settings.setHaptics : null,
          ),
          const SizedBox(height: 12),
          GameAction(
            '진동 확인',
            onTap: settings.vibrationSupported && settings.hapticsEnabled
                ? () => settings.pulse(FeedbackKind.skill, preview: true)
                : null,
            icon: Icons.vibration,
          ),
          const SizedBox(height: 8),
          const Text(
            '진동은 지원되는 기기에서 동작하며, 선택한 설정은 이 브라우저에 저장됩니다.',
            style: TextStyle(
              color: Color(0xffbacdbe),
              fontSize: 12,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 22),
          const InstallControls(),
          const Divider(color: Color(0x557b8c62)),
          const SizedBox(height: 18),
        ],
      );
    },
  );
}
