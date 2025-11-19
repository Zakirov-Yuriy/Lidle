import 'package:flutter/material.dart';
import '../constants.dart';

class AddListingScreen extends StatelessWidget {
  static const String routeName = '/add-listing';

  const AddListingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      appBar: AppBar(
        backgroundColor: primaryBackground,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: const [
            Icon(Icons.close, color: textPrimary),
            SizedBox(width: 8),
            Text(
              'Создайте объявление',
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Опишите товар или услугу',
              style: TextStyle(color: textPrimary, fontSize: 16),
            ),
            const SizedBox(height: 12),

            // Блок добавления изображений
            GestureDetector(
              onTap: () {
                // TODO: Добавить загрузку изображений
              },
              child: Container(
                height: 130,
                decoration: BoxDecoration(
                  color: secondaryBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add_circle_outline, size: 36, color: textMuted),
                      SizedBox(height: 8),
                      Text(
                        'Добавить изображение до 10',
                        style: TextStyle(color: textMuted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
            _buildTextField(label: 'Заголовок объявления', hint: '4-к. квартира', minLength: 16),
            const SizedBox(height: 16),
            _buildDropdown(label: 'Категория', hint: 'Выбрать'),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Описание',
              hint: 'Объявление от собственника...',
              minLength: 70,
              maxLines: 4,
            ),

            const SizedBox(height: 24),
            const Text('Сортировка', style: TextStyle(color: textPrimary, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildChoiceButton('Частное лицо', true),
                const SizedBox(width: 12),
                _buildChoiceButton('Бизнес', false),
              ],
            ),

            const SizedBox(height: 24),
            const Text('Ваши контактные данные', style: TextStyle(color: textPrimary, fontSize: 16)),
            const SizedBox(height: 16),
            _buildDropdown(label: 'Местоположение', hint: 'Ваш город'),
            const SizedBox(height: 16),
            _buildTextField(label: 'Контактное лицо', hint: 'Александр'),
            const SizedBox(height: 16),
            _buildTextField(label: 'Электронная почта', hint: 'AlexAlex@mail.ru'),
            const SizedBox(height: 16),
            _buildTextField(label: 'Номер телефона', hint: '+7 949 456 65 56'),

            const SizedBox(height: 32),
            _buildButton('Предпросмотр', onPressed: () {}),
            const SizedBox(height: 12),
            _buildButton('Опубликовать', onPressed: () {}, isPrimary: true),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    int minLength = 0,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textPrimary, fontSize: 14)),
        const SizedBox(height: 6),
        TextField(
          maxLines: maxLines,
          style: const TextStyle(color: textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: textMuted),
            filled: true,
            fillColor: formBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (minLength > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Введите не менее $minLength символов',
              style: const TextStyle(color: textMuted, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildDropdown({required String label, required String hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textPrimary, fontSize: 14)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: formBackground,
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: null,
              hint: Text(hint, style: const TextStyle(color: textMuted)),
              items: const [],
              onChanged: (value) {},
              dropdownColor: formBackground,
              isExpanded: true,
              iconEnabledColor: textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceButton(String text, bool selected) {
    return Expanded(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: selected ? activeIconColor : formBackground,
          border: Border.all(
            color: selected ? activeIconColor : textMuted,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: selected ? Colors.white : textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(String text, {required VoidCallback onPressed, bool isPrimary = false}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? activeIconColor : Colors.transparent,
          side: isPrimary ? null : const BorderSide(color: Colors.white),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: Text(text, style: TextStyle(color: isPrimary ? Colors.white : textPrimary)),
      ),
    );
  }
}
