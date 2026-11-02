import 'package:flutter/material.dart';
import 'package:dayverse_book/service/app_update_service.dart';

class UpdateDialog extends StatelessWidget {
  final AppUpdateInfo info;
  final Future<void> Function()? onLater;

  const UpdateDialog({
    super.key,
    required this.info,
    this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    final isForce = info.requirement == UpdateRequirement.force;

    return WillPopScope(
      onWillPop: () async => !isForce,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1B2C2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          info.title,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          info.message,
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'kopub',
            fontSize: 15,
            height: 1.45,
          ),
        ),
        actions: [
          if (!isForce)
            TextButton(
              onPressed: () async {
                if (onLater != null) {
                  await onLater!();
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text(
                '나중에',
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'kopub',
                ),
              ),
            ),
          TextButton(
            onPressed: () async {
              await AppUpdateService.openStore();
            },
            child: const Text(
              '업데이트',
              style: TextStyle(
                color: Colors.amberAccent,
                fontFamily: 'kopub',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}