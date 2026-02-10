import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

// Circular Checkbox for this dialog
class _CircularCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CircularCheckbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border.all(
            color: value ? Colors.white54 : Colors.white54,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: value ? accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class ResponsesSortDialog extends StatefulWidget {
  final List<String> currentSort;
  final Function(List<String>) onSortChanged;

  const ResponsesSortDialog({
    super.key,
    required this.currentSort,
    required this.onSortChanged,
  });

  @override
  State<ResponsesSortDialog> createState() => _ResponsesSortDialogState();
}

class _ResponsesSortDialogState extends State<ResponsesSortDialog> {
  late Set<String> _selectedSorts;

  @override
  void initState() {
    super.initState();
    _selectedSorts = widget.currentSort.toSet();
  }

  String _getGroup(String title) {
    if (title == 'Новые' || title == 'Старое') {
      return 'date';
    } else if (title == 'Дорогие' || title == 'Дешевые') {
      return 'price';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
      decoration: const BoxDecoration(
        color: primaryBackground,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with title and close button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close, color: textPrimary, size: 24),
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
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),
          // First group
          _buildOption('Новые'),
          const SizedBox(height: 16),
          _buildOption('Старое'),
          const SizedBox(height: 25),
          const Divider(color: Color(0xFF404854), height: 1),
          const SizedBox(height: 25),
          // Second group
          _buildOption('Дорогие'),
          const SizedBox(height: 16),
          _buildOption('Дешевые'),
        ],
      ),
    );
  }

  Widget _buildOption(String title) {
    final isSelected = _selectedSorts.contains(title);
    final currentGroup = _getGroup(title);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedSorts.remove(title);
          } else {
            // Remove other options from the same group
            _selectedSorts.removeWhere(
              (item) => _getGroup(item) == currentGroup,
            );
            _selectedSorts.add(title);
          }
        });
        widget.onSortChanged(_selectedSorts.toList());
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
          _CircularCheckbox(
            value: isSelected,
            onChanged: (bool value) {
              setState(() {
                if (value) {
                  // Remove other options from the same group
                  _selectedSorts.removeWhere(
                    (item) => _getGroup(item) == currentGroup,
                  );
                  _selectedSorts.add(title);
                } else {
                  _selectedSorts.remove(title);
                }
              });
              widget.onSortChanged(_selectedSorts.toList());
            },
          ),
        ],
      ),
    );
  }
}
