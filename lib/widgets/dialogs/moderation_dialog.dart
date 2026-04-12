import 'package:flutter/material.dart';
import '../../constants.dart';

class ModerationDialog extends StatelessWidget {
  final VoidCallback onContinue;

  const ModerationDialog({
    Key? key,
    required this.onContinue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: defaultPadding),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(defaultPadding, 12, 12, defaultPadding),
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close, color: textPrimary, size: 22),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Объявление на модерации',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: const Text(
                'Ваше объявление отправлено на \nмодерацию. После проверки оно будет \nопубликовано.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onContinue, // 👈 вызываем переданный callback
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color: Color(0xFF00B7FF),
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Продолжить',
                  style: TextStyle(
                    color: Color(0xFF00B7FF),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}