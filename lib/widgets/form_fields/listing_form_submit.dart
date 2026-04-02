import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

/// ============================================================
/// "Виджет: Блок кнопок отправки формы добавления объявления"
/// ============================================================
/// Компонент содержит две кнопки:
/// - Кнопка "Предпросмотр" для проверки объявления
/// - Кнопка "Опубликовать" для публикации объявления
/// ============================================================
class ListingFormSubmit extends StatelessWidget {
  /// Callback для кнопки "Предпросмотр"
  final VoidCallback onPreview;

  /// Callback для кнопки "Опубликовать"
  final VoidCallback onPublish;

  /// Текст на кнопке предпросмотра (по умолчанию "Предпросмотр")
  final String previewLabel;

  /// Текст на кнопке публикации (по умолчанию "Опубликовать")
  final String publishLabel;

  /// Активна ли кнопка "Опубликовать" (по умолчанию да)
  final bool isPublishEnabled;

  const ListingFormSubmit({
    required this.onPreview,
    required this.onPublish,
    this.previewLabel = 'Предпросмотр',
    this.publishLabel = 'Опубликовать',
    this.isPublishEnabled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Кнопка "Предпросмотр"
        _buildButton(
          label: previewLabel,
          onPressed: onPreview,
          isPrimary: false,
        ),
        const SizedBox(height: 12),
        
        // Кнопка "Опубликовать"
        _buildButton(
          label: publishLabel,
          onPressed: isPublishEnabled ? onPublish : null,
          isPrimary: true,
          isEnabled: isPublishEnabled,
        ),
      ],
    );
  }

  /// Построение кнопки
  Widget _buildButton({
    required String label,
    required VoidCallback? onPressed,
    required bool isPrimary,
    bool isEnabled = true,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onPressed : null,
      child: Container(
        decoration: BoxDecoration(
          color: isPrimary
              ? (isEnabled ? activeIconColor : Colors.grey)
              : secondaryBackground,
          borderRadius: BorderRadius.circular(8),
          border: !isPrimary
              ? Border.all(color: textSecondary, width: 1)
              : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
