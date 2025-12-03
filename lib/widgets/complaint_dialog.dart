import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/custom_checkbox.dart'; // Import CustomCheckbox

class ComplaintDialog extends StatefulWidget {
  const ComplaintDialog({super.key});

  @override
  State<ComplaintDialog> createState() => _ComplaintDialogState();
}

class _ComplaintDialogState extends State<ComplaintDialog> {
  bool _spamChecked = false;
  bool _incorrectDataChecked = false;
  bool _inappropriateLanguageChecked = false;
  bool _strangeResourcesChecked = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: primaryBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        padding: const EdgeInsets.only(
          top: 25.0,
          left: 25.0,
          right: 25.0,
          bottom: 47.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Оставить жалобу",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            _buildCheckboxRow("Спам", _spamChecked, (bool? value) {
              setState(() {
                _spamChecked = value ?? false;
              });
            }),
            _buildCheckboxRow("Не корректные данные", _incorrectDataChecked, (
              bool? value,
            ) {
              setState(() {
                _incorrectDataChecked = value ?? false;
              });
            }),
            _buildCheckboxRow(
              "Не цензурная лексика\nв объявлении",
              _inappropriateLanguageChecked,
              (bool? value) {
                setState(() {
                  _inappropriateLanguageChecked = value ?? false;
                });
              },
            ),
            _buildCheckboxRow(
              "Ссылки на странные ресурсы",
              _strangeResourcesChecked,
              (bool? value) {
                setState(() {
                  _strangeResourcesChecked = value ?? false;
                });
              },
            ),
            const SizedBox(height: 34), // Increased spacing before buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ===== КНОПКА ОТМЕНА =====
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
                    splashFactory:
                        NoSplash.splashFactory, // без эффекта нажатия
                  ),
                  child: const Text(
                    "Отмена",
                    style: TextStyle(
                      inherit: false, // ВАЖНО — отключает перезапись стиля
                      color: Colors.white,
                      fontSize: 16,
                      decoration: TextDecoration.underline, // подчёркивание
                      decorationColor: Colors.white,
                      decorationThickness: 1.2,
                    ),
                  ),
                ),

                const SizedBox(width: 21),

                // ===== КНОПКА ОТПРАВИТЬ =====
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: activeIconColor, width: 1.4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 25,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    "Отправить",
                    style: TextStyle(
                      color: activeIconColor, // синий текст
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxRow(
    String title,
    bool isChecked,
    ValueChanged<bool?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          CustomCheckbox(
            // Use CustomCheckbox instead of Checkbox
            value: isChecked,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
