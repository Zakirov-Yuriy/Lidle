import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

/// ============================================================
/// "Виджет: Поле для ввода описания объявления"
/// ============================================================
/// Компонент для ввода описания объявления с проверкой
/// минимальной длины текста и подсказкой под полем.
/// ============================================================
class DescriptionField extends StatefulWidget {
  /// Начальное значение описания
  final String? initialDescription;

  /// Минимальная длина описания (по умолчанию 70 символов)
  final int minLength;

  /// Максимальное число строк (по умолчанию 4)
  final int maxLines;

  /// Callback когда описание изменилось
  final ValueChanged<String> onChanged;

  const DescriptionField({
    this.initialDescription,
    this.minLength = 70,
    this.maxLines = 4,
    required this.onChanged,
    super.key,
  });

  @override
  State<DescriptionField> createState() => _DescriptionFieldState();
}

class _DescriptionFieldState extends State<DescriptionField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: formBackground,
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            controller: _controller,
            maxLines: widget.maxLines,
            style: const TextStyle(color: textPrimary),
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              labelText: 'Описание',
              labelStyle: const TextStyle(
                color: textSecondary,
                fontSize: 14,
              ),
              hintText: 'Чем больше информации вы укажете о вашей квартире, '
                  'тем привлекательнее она будет для покупателей. '
                  'Без ссылок, телефонов, матершинных слов.',
              hintStyle: const TextStyle(
                color: Color.fromARGB(150, 255, 255, 255),
                fontSize: 12,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Введите не менее ${widget.minLength} символов',
          style: TextStyle(color: textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}
