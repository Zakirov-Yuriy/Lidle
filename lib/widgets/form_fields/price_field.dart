import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';

/// ============================================================
/// "Виджет: Поле для ввода цены с опциями"
/// ============================================================
/// Компонент для ввода цены с поддержкой:
/// - Основная цена в наиболее часто используемой валюте (₽)
/// - Опция "Возможен торг"
/// - Опция "Без комиссии"
/// ============================================================
class PriceField extends StatefulWidget {
  /// Начальное значение цены (опционально)
  final String? initialPrice;

  /// Начальное значение для опции "Возможен торг"
  final bool initialIsBargain;

  /// Начальное значение для опции "Без комиссии"
  final bool initialIsNoCommission;

  /// Callback когда цена изменилась
  final ValueChanged<String> onPriceChanged;

  /// Callback когда "Возможен торг" изменилось
  final ValueChanged<bool> onIsBargainChanged;

  /// Callback когда "Без комиссии" изменилось
  final ValueChanged<bool> onIsNoCommissionChanged;

  const PriceField({
    this.initialPrice,
    this.initialIsBargain = false,
    this.initialIsNoCommission = false,
    required this.onPriceChanged,
    required this.onIsBargainChanged,
    required this.onIsNoCommissionChanged,
    super.key,
  });

  @override
  State<PriceField> createState() => _PriceFieldState();
}

class _PriceFieldState extends State<PriceField> {
  late TextEditingController _priceController;
  late bool _isBargain;
  late bool _isNoCommission;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(text: widget.initialPrice);
    _isBargain = widget.initialIsBargain;
    _isNoCommission = widget.initialIsNoCommission;
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Цена*',
          style: TextStyle(color: textPrimary, fontSize: 16),
        ),
        const SizedBox(height: 9),
        
        // Поле для ввода цены
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: formBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: textPrimary),
                        onChanged: widget.onPriceChanged,
                        decoration: const InputDecoration(
                          hintText: '1 000 000',
                          hintStyle: TextStyle(
                            color: Color.fromARGB(255, 255, 255, 255),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Отображение валюты
            Container(
              decoration: BoxDecoration(
                color: formBackground,
                borderRadius: BorderRadius.circular(6),
              ),
              width: 53,
              height: 48,
              alignment: Alignment.center,
              child: Text(
                '₽',
                style: TextStyle(color: textPrimary, fontSize: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        
        // Опция "Возможен торг"
        _buildCheckboxOption(
          label: 'Возможен торг',
          value: _isBargain,
          onChanged: (v) {
            setState(() => _isBargain = v);
            widget.onIsBargainChanged(v);
          },
        ),
        const SizedBox(height: 12),
        
        // Опция "Без комиссии"
        _buildCheckboxOption(
          label: 'Без комиссии',
          value: _isNoCommission,
          onChanged: (v) {
            setState(() => _isNoCommission = v);
            widget.onIsNoCommissionChanged(v);
          },
        ),
      ],
    );
  }

  /// Построение опции с чекбоксом
  Widget _buildCheckboxOption({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: Text(
              label,
              style: const TextStyle(color: textPrimary, fontSize: 14),
            ),
          ),
        ),
        CustomCheckbox(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
