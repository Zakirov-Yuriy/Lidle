import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import '../components/custom_checkbox.dart';

class ResponsesSortDialog extends StatefulWidget {
  final String currentSort;
  final Function(String) onSortChanged;

  const ResponsesSortDialog({
    super.key,
    required this.currentSort,
    required this.onSortChanged,
  });

  @override
  State<ResponsesSortDialog> createState() => _ResponsesSortDialogState();
}

class _ResponsesSortDialogState extends State<ResponsesSortDialog> {
  late String _selectedSort;

  @override
  void initState() {
    super.initState();
    _selectedSort = widget.currentSort;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 10, 13, 30),
      decoration: const BoxDecoration(
        color: primaryBackground,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const Text(
            'Сортировать',
            style: TextStyle(
              color: textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 25),
          _buildOption('По цене'),
          const SizedBox(height: 20),
          _buildOption('По дате публикации'),
        ],
      ),
    );
  }

  Widget _buildOption(String title) {
    final isSelected = _selectedSort == title;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedSort = title;
        });
        widget.onSortChanged(title);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          CustomCheckbox(
            value: isSelected,
            onChanged: (bool value) {
              if (value) {
                setState(() {
                  _selectedSort = title;
                });
                widget.onSortChanged(title);
              }
            },
          ),
        ],
      ),
    );
  }
}
