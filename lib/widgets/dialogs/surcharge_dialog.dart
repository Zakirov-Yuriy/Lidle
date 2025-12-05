// ============================================================
//  "Диалог доплаты"
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';

class SurchargeDialog extends StatefulWidget {
  final bool initialPerDay;
  final bool initialPerHour;

  const SurchargeDialog({
    super.key,
    this.initialPerDay = false,
    this.initialPerHour = false,
  });

  @override
  State<SurchargeDialog> createState() => _SurchargeDialogState();
}

class _SurchargeDialogState extends State<SurchargeDialog> {
  late bool _perDaySelected;
  late bool _perHourSelected;

  @override
  void initState() {
    super.initState();
    _perDaySelected = widget.initialPerDay;
    _perHourSelected = widget.initialPerHour;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: primaryBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      titlePadding: const EdgeInsets.all(20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.all(20),
      title: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close, color: Colors.white70),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Доплата сверх лимита",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCheckboxRow("За сутки", _perDaySelected, (bool? value) {
            setState(() {
              _perDaySelected = value ?? false;
              if (_perDaySelected) _perHourSelected = false;
            });
          }),
          const SizedBox(height: 10),
          _buildCheckboxRow("За часы", _perHourSelected, (bool? value) {
            setState(() {
              _perHourSelected = value ?? false;
              if (_perHourSelected) _perDaySelected = false;
            });
          }),
        ],
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          
          children: [
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(100, 35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Close without applying changes
              },
              child: const Text(
                'Отмена',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  decoration: TextDecoration.underline,
                  decorationColor: textPrimary,
                ),
              ),
            ),
            // const SizedBox(width: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.transparent,
                side: const BorderSide(color: activeIconColor),
                minimumSize: const Size(100, 35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop({
                  "perDay": _perDaySelected,
                  "perHour": _perHourSelected
                }); // Close and apply changes
              },
              child: const Text(
                'Готово',
                style: TextStyle(color: activeIconColor, fontSize: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCheckboxRow(
    String title,
    bool value,
    Function(bool?) onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        CustomCheckbox(value: value, onChanged: onChanged),
      ],
    );
  }
}
