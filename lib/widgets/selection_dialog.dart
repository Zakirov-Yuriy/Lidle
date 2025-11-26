import 'package:flutter/material.dart';
import '../constants.dart';
import 'custom_checkbox.dart';

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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 10, 13, 20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [IconButton(
                  icon: const Icon(Icons.close, color: textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.title,
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
                  children:
                      widget.options.map((option) => _buildCheckbox(option)).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
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
                const SizedBox(width: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    fixedSize: const Size(127, 35),
                    side: const BorderSide(color: activeIconColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    widget.onSelectionChanged(_tempSelectedOptions);
                    Navigator.of(context).pop();
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
          Text(title,
              style: const TextStyle(color: textPrimary, fontSize: 16)),
          CustomCheckbox(
            value: _tempSelectedOptions.contains(title),
            onChanged: (bool value) {
              setState(() {
                if (widget.allowMultipleSelection) {
                  if (value) {
                    _tempSelectedOptions.add(title);
                  } else {
                    _tempSelectedOptions.remove(title);
                  }
                } else {
                  if (value) {
                    _tempSelectedOptions.clear();
                    _tempSelectedOptions.add(title);
                  } else {
                    _tempSelectedOptions.remove(title);
                  }
                }
              });
            },
          ),
        ],
      ),
    );
  }
}
