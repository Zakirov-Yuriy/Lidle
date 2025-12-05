import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants.dart';

// ============================================================
// "Виджет: Экран добавления объявления"
// ============================================================
class AddListingScreen extends StatefulWidget {
  static const String routeName = '/add-listing';

  const AddListingScreen({super.key});

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

// ============================================================
// "Класс состояния: Управление состоянием экрана добавления объявления"
// ============================================================
class _AddListingScreenState extends State<AddListingScreen> {
  bool isIndividualSelected = true;
  bool isPreviewSelected = false;
  bool isPublishSelected = false;

// ============================================================
// "Логика: Переключение выбора типа пользователя (частное лицо/бизнес)"
// ============================================================
  void _toggleSelection(bool isIndividual) {
    setState(() {
      isIndividualSelected = isIndividual;
    });
  }

// ============================================================
// "Виджет: Основной интерфейс экрана добавления объявления"
// ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 3, bottom: 20),
                    child: SvgPicture.asset(logoAsset, height: logoHeight),
                  ),
                  const Spacer(),
                ],
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: textPrimary),
                  ),
                  SizedBox(width: 13),
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
              SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.only(bottom: 17.0),
                child: const Text(
                  'Опишите товар или услугу',
                  style: TextStyle(color: textPrimary, fontSize: 16),
                 
                ),
              ),
              GestureDetector(
                onTap: () {
                },
                child: Container(
                  height: 126,
                  decoration: BoxDecoration(
                    color: secondaryBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.add_circle_outline,
                          size: 36,
                          color: textMuted,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Добавить изображение до 10',
                          style: TextStyle(color: textMuted, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 15),
              _buildTextField(
                label: 'Заголовок объявления',
                hint: '4-к. квартира',
                minLength: 16,
              ),
              const SizedBox(height: 11),
              _buildDropdown(label: 'Категория', hint: 'Выбрать'),
              const SizedBox(height: 15),
              _buildTextField(
                label: 'Описание',
                hint: 'Объявление от coбcтвeнника! Предлагaю сoбствeнную пpоcтopную ceмeйную квapтиpу нa тихой улице в престижнoм pайоне Mосквы.',
                minLength: 70,
                maxLines: 4,
              ),

              const SizedBox(height: 19),
              const Text(
                'Сортировка',
                style: TextStyle(color: textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildChoiceButton('Частное лицо', isIndividualSelected, () => _toggleSelection(true)),
                  const SizedBox(width: 10),
                  _buildChoiceButton('Бизнес', !isIndividualSelected, () => _toggleSelection(false)),
                ],
              ),

              const SizedBox(height: 27),
              const Text(
                'Ваши контактные данные',
                style: TextStyle(color: textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 18),
              _buildDropdown(label: 'Местоположение', hint: 'Ваш город'),
              const SizedBox(height: 9),
              _buildTextField(label: 'Контактное лицо', hint: 'Александр'),
              const SizedBox(height: 9),
              _buildTextField(
                label: 'Электронная почта',
                hint: 'AlexAlex@mail.ru',
              ),
              const SizedBox(height: 9),
              _buildTextField(
                label: 'Номер телефона',
                hint: '+7 949 456 65 56',
              ),

              const SizedBox(height: 32),
              _buildButton('Предпросмотр', onPressed: () {}),
              const SizedBox(height: 10),
              _buildButton('Опубликовать', onPressed: () {}, isPrimary: true),
            ],
          ),
        ),
      ),
    );
  }

// ============================================================
// "Виджет: Построение текстового поля с валидацией"
// ============================================================
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
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              'Введите не менее $minLength символов',
              style: const TextStyle(color: textMuted, fontSize: 12),
            ),
          ),
      ],
    );
  }

// ============================================================
// "Виджет: Построение выпадающего списка с навигацией"
// ============================================================
  Widget _buildDropdown({required String label, required String hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textPrimary, fontSize: 14)),
        const SizedBox(height: 9),
        GestureDetector(
          onTap: () {
            if (label == 'Категория') {
              Navigator.pushNamed(context, '/category-selection');
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: formBackground,
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: null,
                hint: Text(hint, style: const TextStyle(color: textMuted)),
                items: label == 'Категория' ? null : const [],
                onChanged: label == 'Категория' ? null : (value) {},
                dropdownColor: formBackground,
                isExpanded: true,
                iconEnabledColor: textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }

// ============================================================
// "Виджет: Построение кнопки выбора типа"
// ============================================================
  Widget _buildChoiceButton(String text, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 35,
          decoration: BoxDecoration(
            color: selected ? activeIconColor : formBackground,
            border: Border.all(color: selected ? activeIconColor : textMuted),
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
      ),
    );
  }

// ============================================================
// "Виджет: Построение кнопки действия"
// ============================================================
  Widget _buildButton(
    String text, {
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? activeIconColor : primaryBackground,
          side: isPrimary ? null : const BorderSide(color: Colors.white),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(color: isPrimary ? Colors.white : textPrimary),
        ),
      ),
    );
  }
}
