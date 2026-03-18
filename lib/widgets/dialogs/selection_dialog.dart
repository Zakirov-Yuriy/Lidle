// ============================================================
//  "Диалог выбора"
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import '../components/custom_checkbox.dart';
import '../components/custom_radio_button.dart';

class SelectionDialog extends StatefulWidget {
  final String title;
  final List<String> options;
  final Set<String> selectedOptions;
  final Function(Set<String>) onSelectionChanged;
  final bool allowMultipleSelection;

  const SelectionDialog({
    super.key,
    required this.title,
    required this.options,
    required this.selectedOptions,
    required this.onSelectionChanged,
    this.allowMultipleSelection = true,
  });

  @override
  _SelectionDialogState createState() => _SelectionDialogState();
}

class _SelectionDialogState extends State<SelectionDialog> {
  late Set<String> _tempSelectedOptions;

  @override
  void initState() {
    super.initState();
    _tempSelectedOptions = widget.selectedOptions;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF222E3A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 10, 13, 20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: textPrimary),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 23),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.options
                      .map((option) => _buildCheckbox(option))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(127, 35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pop(); // Close without applying changes
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
                    minimumSize: const Size(127, 35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    widget.onSelectionChanged(_tempSelectedOptions);
                    Navigator.of(context).pop(); // Close and apply changes
                  },
                  child: const Text(
                    'Готово',
                    style: TextStyle(color: activeIconColor, fontSize: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (widget.allowMultipleSelection) {
                    if (_tempSelectedOptions.contains(title)) {
                      _tempSelectedOptions.remove(title);
                    } else {
                      _tempSelectedOptions.add(title);
                    }
                  } else {
                    // For single selection (Style D1), clear existing and add new
                    if (_tempSelectedOptions.contains(title)) {
                      _tempSelectedOptions.remove(title);
                    } else {
                      _tempSelectedOptions.clear();
                      _tempSelectedOptions.add(title);
                    }
                  }
                });
              },
              child: Text(
                title,
                style: const TextStyle(color: textPrimary, fontSize: 16),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (widget.allowMultipleSelection)
            // 🔲 Множественный выбор - CHECKBOXES (квадратные)
            CustomCheckbox(
              value: _tempSelectedOptions.contains(title),
              onChanged: (bool value) {
                setState(() {
                  if (value) {
                    _tempSelectedOptions.add(title);
                  } else {
                    _tempSelectedOptions.remove(title);
                  }
                });
              },
            )
          else
            // 🔘 Одиночный выбор Style D1 - RADIO BUTTONS (круглые с синим бордером)
            CustomRadioButton<String>(
              value: title,
              groupValue: _tempSelectedOptions.isNotEmpty
                  ? _tempSelectedOptions.first
                  : null,
              onChanged: (String? value) {
                if (value != null) {
                  setState(() {
                    _tempSelectedOptions.clear();
                    _tempSelectedOptions.add(value);
                  });
                } else if (value == null) {
                  setState(() {
                    _tempSelectedOptions.remove(title);
                  });
                }
              },
              selectedBorderColor: const Color(
                0xFF888888,
              ), // Blue border when selected
              unselectedBorderColor: const Color(
                0xFF888888,
              ), // Gray border when unselected
              selectedFillColor: const Color(
                0xFF00A6FF,
              ), // Blue fill when selected
            ),
        ],
      ),
    );
  }
}
