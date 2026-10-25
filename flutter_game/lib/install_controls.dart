import 'package:flutter/material.dart';
import 'game_ui.dart';
import 'install_bridge.dart';
import 'panel_controls.dart';
import 'settings_controls.dart';

class InstallControls extends StatefulWidget {
  const InstallControls({super.key});
  @override
  State<InstallControls> createState() => _InstallControlsState();
}

class _InstallControlsState extends State<InstallControls> {
  late final bridge = createInstallBridge();
  bool pending = false;
  @override
  void initState() {
    super.initState();
    bridge.listen(() {
      if (mounted) setState(() => pending = false);
    });
  }

  @override
  void dispose() {
    bridge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      GameAction(
        bridge.installed
            ? '앱 설치됨'
            : pending
            ? '설치 확인 중'
            : '앱 설치',
        onTap: bridge.installed || pending
            ? null
            : () {
                if (!bridge.available) {
                  showDialog<void>(
                    context: context,
                    builder: (context) => GameNoticeDialog(
                      title: '앱 설치 안내',
                      message: bridge.message,
                      icon: Icons.install_mobile,
                    ),
                  );
                  return;
                }
                setState(() => pending = true);
                bridge.request();
              },
        icon: bridge.installed
            ? Icons.check_circle_outline
            : Icons.install_mobile,
      ),
      const SizedBox(height: 8),
      Text(
        bridge.message,
        style: const TextStyle(color: cream, fontSize: 13, height: 1.6),
      ),
      const SizedBox(height: 18),
    ],
  );
}
