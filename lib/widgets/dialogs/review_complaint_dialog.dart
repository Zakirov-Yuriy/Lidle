// ============================================================
//  "Диалог жалобы на отзыв"
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';

class ReviewComplaintDialog extends StatefulWidget {
  const ReviewComplaintDialog({super.key});

  @override
  State<ReviewComplaintDialog> createState() => _ReviewComplaintDialogState();
}

class _ReviewComplaintDialogState extends State<ReviewComplaintDialog> {
  bool _incorrectInfoChecked = false;
  bool _insultsChecked = false;
  bool _spamChecked = false;
  bool _strangeResourcesChecked = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: formBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Пожаловаться",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 25),
                _buildCheckboxRow("Некорректная информация", _incorrectInfoChecked,
                    (value) {
                  setState(() {
                    _incorrectInfoChecked = value;
                  });
                }),
                _buildCheckboxRow("Оскорбления", _insultsChecked, (value) {
                  setState(() {
                    _insultsChecked = value;
                  });
                }),
                _buildCheckboxRow("Спам", _spamChecked, (value) {
                  setState(() {
                    _spamChecked = value;
                  });
                }),
                _buildCheckboxRow(
                    "Ссылки на странные ресурсы", _strangeResourcesChecked,
                    (value) {
                  setState(() {
                    _strangeResourcesChecked = value;
                  });
                }),
                const SizedBox(height: 35),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        "Отмена",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    OutlinedButton(
                      onPressed: () {
                        // TODO: Implement complaint sending logic
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: activeIconColor, width: 1.5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "Отправить",
                        style: TextStyle(
                          color: activeIconColor,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxRow(
    String title,
    bool isChecked,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          CustomCheckbox(
            value: isChecked,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
