// ============================================================
//  "Диалог удаления чата"
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

class DeleteChatDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const DeleteChatDialog({super.key, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: primaryBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Удалить чат',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            RichText(
              textAlign: TextAlign.start,
              text: const TextSpan(
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
                children: [
                  TextSpan(
                    text: 'Внимание: ',
                    style: TextStyle(
                      color: Color(0xFFCCCC00),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: 'если вы хотите\nудалить чат'),
                ],
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Потрердите действие',
              textAlign: TextAlign.start,
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    minimumSize: Size.zero,
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    splashFactory: NoSplash.splashFactory,
                  ),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(
                      inherit: false,
                      color: Colors.white,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                      decorationThickness: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 21),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onConfirm();
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: accentColor, width: 1.4),
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Подтвердить',
                    style: TextStyle(color: accentColor, fontSize: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
