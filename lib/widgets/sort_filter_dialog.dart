import 'package:flutter/material.dart';
import '../constants.dart';

enum SortOption {
  newest,
  oldest,
  mostExpensive,
  cheapest,
}

class SortFilterDialog extends StatefulWidget {
  final Function(SortOption) onSortChanged;

  const SortFilterDialog({super.key, required this.onSortChanged});

  @override
  _SortFilterDialogState createState() => _SortFilterDialogState();
}

class _SortFilterDialogState extends State<SortFilterDialog> {
  SortOption? _selectedOption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: const BoxDecoration(
        color: Color(0xFF222E3A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Сортировать товар',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildRadio('Новые', SortOption.newest),
          _buildRadio('Старое', SortOption.oldest),
          _buildRadio('Дорогие', SortOption.mostExpensive),
          _buildRadio('Дешевые', SortOption.cheapest),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRadio(String title, SortOption option) {
    return RadioListTile<SortOption>(
      title: Text(title, style: const TextStyle(color: textPrimary)),
      value: option,
      groupValue: _selectedOption,
      onChanged: (SortOption? value) {
        setState(() {
          _selectedOption = value;
        });
        if (value != null) {
          widget.onSortChanged(value);
        }
        Navigator.of(context).pop();
      },
      activeColor: Colors.blue,
    );
  }
}
