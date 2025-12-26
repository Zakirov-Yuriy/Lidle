import 'package:flutter/material.dart';
import './components/custom_checkbox.dart';

enum SortOption {
  byDate,
  byRating,
}

class SortDialog extends StatefulWidget {
  final SortOption? initialSortOption;

  const SortDialog({super.key, this.initialSortOption});

  @override
  State<SortDialog> createState() => _SortDialogState();
}

class _SortDialogState extends State<SortDialog> {
  SortOption? _selectedSortOption;

  @override
  void initState() {
    super.initState();
    _selectedSortOption = widget.initialSortOption;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      backgroundColor: const Color(0xFF243241), // Соответствует фону из reviews_empty_page.dart
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Сортировать',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
               
              ],
            ),
            const SizedBox(height: 20),
            _buildSortOption(context, 'По дате', SortOption.byDate),
            _buildSortOption(context, 'По оценке', SortOption.byRating),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(BuildContext context, String title, SortOption option) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSortOption = option;
        });
        Navigator.of(context).pop(option); // Возвращаем выбранную опцию
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            CustomCheckbox(
              value: _selectedSortOption == option,
              onChanged: (bool value) {
                if (value) {
                  setState(() {
                    _selectedSortOption = option;
                  });
                  Navigator.of(context).pop(option); // Возвращаем выбранную опцию
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
