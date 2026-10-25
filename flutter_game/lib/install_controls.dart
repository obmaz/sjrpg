import 'package:flutter/material.dart';
import 'game_ui.dart';
import 'install_bridge.dart';

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
      OutlinedButton.icon(
        onPressed: bridge.installed || pending
            ? null
            : () {
                if (!bridge.available) {
                  showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('앱 설치 안내'),
                      content: Text(bridge.message),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('확인'),
                        ),
                      ],
                    ),
                  );
                  return;
                }
                setState(() => pending = true);
                bridge.request();
              },
        icon: Icon(
          bridge.installed ? Icons.check_circle_outline : Icons.install_mobile,
        ),
        label: Text(
          bridge.installed
              ? '앱 설치됨'
              : pending
              ? '설치 확인 중'
              : '앱 설치',
        ),
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
