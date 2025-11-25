import 'package:flutter/material.dart';
import '../constants.dart';
import 'custom_checkbox.dart';

enum SortOption {
  newest,
  oldest,
  mostExpensive,
  cheapest,
}

class SortFilterDialog extends StatefulWidget {
  final Function(Set<SortOption>) onSortChanged;

  const SortFilterDialog({super.key, required this.onSortChanged});

  @override
  _SortFilterDialogState createState() => _SortFilterDialogState();
}

class _SortFilterDialogState extends State<SortFilterDialog> {
  Set<SortOption> _selectedOptions = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10.0, right: 13, left: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF222E3A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(0.0),
          topRight: Radius.circular(0.0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [

              IconButton(
                icon: const Icon(Icons.close, color: textPrimary),
                onPressed: () => Navigator.of(context).pop(),

              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Сортировать товар',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

            ],
          ),
          const SizedBox(height: 23),
          _buildCheckbox('Новые', SortOption.newest),
          const SizedBox(height: 23),
          _buildCheckbox('Старое', SortOption.oldest),
          const SizedBox(height: 23),
          _buildCheckbox('Дорогие', SortOption.mostExpensive),
          const SizedBox(height: 23),
          _buildCheckbox('Дешевые', SortOption.cheapest),
          const SizedBox(height: 60),
          
          
        ],
        
      ),
    );
  }
  

  Widget _buildCheckbox(String title, SortOption option) {
    return Padding(
      padding: const EdgeInsets.only(right: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: textPrimary, fontSize: 16)),
          CustomCheckbox(
            value: _selectedOptions.contains(option),
            onChanged: (bool value) {
              setState(() {
                if (value) {
                  _selectedOptions.add(option);
                } else {
                  _selectedOptions.remove(option);
                }
              });
              widget.onSortChanged(_selectedOptions);
            },
          ),
        ],
      ),
    );
  }
}
