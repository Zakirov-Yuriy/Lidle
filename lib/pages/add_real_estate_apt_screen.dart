import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants.dart';

class AddRealEstateAptScreen extends StatefulWidget {
  static const String routeName = '/add-real-estate-apt';

  const AddRealEstateAptScreen({super.key});

  @override
  State<AddRealEstateAptScreen> createState() =>
      _AddRealEstateAptScreenState();
}

class _AddRealEstateAptScreenState extends State<AddRealEstateAptScreen> {
  // Переключатели
  bool isIndividualSelected = true; // Частное лицо / Бизнес
  bool isSecondarySelected = true; // Вторичка / Новостройка
  bool isMortgageYes = true; // Ипотека Да / Нет

  // Чекбоксы цены
  bool isBargain = false; // Возможен торг
  bool isNoCommission = false; // Без комиссии
  bool isExchange = false; // Возможность обмена
  bool isPledge = false; // Готов принять в залог
  bool isUrgent = false; // Срочно
  bool isInstallment = false; // Рассрочка
  bool isRemoteDeal = false; // Удалённая сделка
  bool isClientPrice = false; // Клиент может предложить свою цену

  void _togglePersonType(bool isIndividual) {
    setState(() => isIndividualSelected = isIndividual);
  }

  void _toggleMarketType(bool isSecondary) {
    setState(() => isSecondarySelected = isSecondary);
  }

  void _toggleMortgage(bool yes) {
    setState(() => isMortgageYes = yes);
  }

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
              // Логотип
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 41, bottom: 28),
                    child: SvgPicture.asset(logoAsset, height: logoHeight),
                  ),
                  const Spacer(),
                ],
              ),

              // Заголовок
              Row(
                children: const [
                  Icon(Icons.close, color: textPrimary),
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
              const SizedBox(height: 17),

              // Блок "Опишите товар или услугу"
              const Text(
                'Опишите товар или услугу',
                style: TextStyle(color: textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 17),

              // Добавить изображение
              GestureDetector(
                onTap: () {
                  // TODO: реализовать загрузку изображений
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
                        Icon(Icons.add_a_photo_outlined,
                            color: textSecondary),
                        SizedBox(height: 10),
                        Text(
                          'Добавить изображение',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _buildTextField(
                label: 'Заголовок объявления',
                hint: 'Например, уютная 2-комнатная квартира',
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Категория',
                hint: 'Продажа квартир',
                onTap: () {
                  // Если нужно открыть экран выбора категории:
                  // Navigator.pushNamed(context, '/category-selection');
                },
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Описание',
                hint:
                    'Чем больше информации вы укажете о вашей квартире, тем привлекательнее она будет для покупателей. Без ссылок, телефонов, матершинных слов.',
                minLength: 70,
                maxLines: 4,
              ),

              const SizedBox(height: 24),

              // Цена
              const Text(
                'Цена*',
                style: TextStyle(color: textPrimary, fontSize: 14),
              ),
              const SizedBox(height: 9),
              Container(
                decoration: BoxDecoration(
                  color: formBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: textPrimary),
                        decoration: const InputDecoration(
                          hintText: '1 000 000',
                          hintStyle:
                              TextStyle(color: textSecondary, fontSize: 14),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        // TODO: доп. настройки цены
                      },
                      icon: const Icon(Icons.more_vert, color: textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Чекбоксы по цене
              _buildCheckbox(
                title: 'Возможен торг',
                value: isBargain,
                onChanged: (v) => setState(() => isBargain = v),
              ),
              _buildCheckbox(
                title: 'Без комиссии',
                value: isNoCommission,
                onChanged: (v) => setState(() => isNoCommission = v),
              ),
              _buildCheckbox(
                title: 'Возможность обмена',
                value: isExchange,
                onChanged: (v) => setState(() => isExchange = v),
              ),
              _buildCheckbox(
                title: 'Готов принять в залог',
                value: isPledge,
                onChanged: (v) => setState(() => isPledge = v),
              ),
              _buildCheckbox(
                title: 'Срочно',
                value: isUrgent,
                onChanged: (v) => setState(() => isUrgent = v),
              ),
              _buildCheckbox(
                title: 'Рассрочка',
                value: isInstallment,
                onChanged: (v) => setState(() => isInstallment = v),
              ),
              _buildCheckbox(
                title: 'Удалённая сделка',
                value: isRemoteDeal,
                onChanged: (v) => setState(() => isRemoteDeal = v),
              ),
              _buildCheckbox(
                title: 'Клиент может предложить свою цену',
                value: isClientPrice,
                onChanged: (v) => setState(() => isClientPrice = v),
              ),

              const SizedBox(height: 24),

              // Ипотека
              const Text(
                'Ипотека',
                style: TextStyle(color: textPrimary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildChoiceButton(
                    'Да',
                    isMortgageYes,
                    () => _toggleMortgage(true),
                  ),
                  const SizedBox(width: 10),
                  _buildChoiceButton(
                    'Нет',
                    !isMortgageYes,
                    () => _toggleMortgage(false),
                  ),
                ],
              ),

              const SizedBox(height: 27),
              // Рассрочка
              const Text(
                'Рассрочка',
                style: TextStyle(color: textPrimary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildChoiceButton(
                    'Да',
                    isMortgageYes,
                    () => _toggleMortgage(true),
                  ),
                  const SizedBox(width: 10),
                  _buildChoiceButton(
                    'Нет',
                    !isMortgageYes,
                    () => _toggleMortgage(false),
                  ),
                ],
              ),

              const SizedBox(height: 27),

              // Блок характеристик квартиры
              // const Text(
              //   'Параметры недвижимости',
              //   style: TextStyle(color: textPrimary, fontSize: 16),
              // ),
              // const SizedBox(height: 18),

              _buildDropdown(
                label: 'Тип дома',
                hint: 'Столбец',
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Название ЖК',
                hint: 'Название жилого комплекса',
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Номер квартиры',
                hint: 'Номер квартиры',
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Этаж*',
                hint: 'Укажите этаж',
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Этажность*',
                hint: 'Общее количество этажей',
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Тип сделки',
                hint: 'Выбрать',
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Общая площадь(м²)*',
                hint: 'Цифрами',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Тип стен',
                hint: 'Выбрать',
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Класс жилья',
                hint: 'Выбрать',
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Количество комнат*',
                hint: 'Цифрами',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Планировка',
                hint: 'Выбрать',
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Санузел',
                hint: 'Выбрать',
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Отделка',
                hint: 'Выбрать',
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Ремонт',
                hint: 'Выбрать',
              ),
              const SizedBox(height: 9),

              // Мебелирован
              const Text(
                'Мебелирован',
                style: TextStyle(color: textPrimary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildChoiceButton(
                    'Да',
                    true,
                    () {
                      // TODO: сохранить значение
                    },
                  ),
                  const SizedBox(width: 10),
                  _buildChoiceButton(
                    'Нет',
                    false,
                    () {
                      // TODO: сохранить значение
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),

              _buildDropdown(
                label: 'Бытовая техника',
                hint: 'Выбрать',
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Мультимедиа',
                hint: 'Цифрами',
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Комфорт',
                hint: 'Выбрать',
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Коммуникации',
                hint: 'Выбрать',
              ),
              const SizedBox(height: 9),

              const Text(
                'Вид объекта',
                style: TextStyle(color: textPrimary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildChoiceButton(
                    'Вторичка',
                    isSecondarySelected,
                    () => _toggleMarketType(true),
                  ),
                  const SizedBox(width: 10),
                  _buildChoiceButton(
                    'Новостройка',
                    !isSecondarySelected,
                    () => _toggleMarketType(false),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              _buildTextField(
                label: 'Год постройки',
                hint: 'Укажите год',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Площадь кухни(м²)',
                hint: 'Цифрами',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Инфраструктура (до 500 метров)',
                hint: 'Выбрать',
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Ландшафт (до 1 км)',
                hint: 'Выбрать',
              ),

              const SizedBox(height: 27),

              // Частное лицо / Бизнес
              const Text(
                'Частное лицо / Бизнес*',
                style: TextStyle(color: textPrimary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildChoiceButton(
                    'Частное лицо',
                    isIndividualSelected,
                    () => _togglePersonType(true),
                  ),
                  const SizedBox(width: 10),
                  _buildChoiceButton(
                    'Бизнес',
                    !isIndividualSelected,
                    () => _togglePersonType(false),
                  ),
                ],
              ),

              const SizedBox(height: 27),
              // Блок характеристик квартиры
              const Text(
                'Частное до 2х объявлений. Бизнес от 2х и более объявлений.',
                style: TextStyle(color: textPrimary, fontSize: 12),
              ),
              const SizedBox(height: 18),

              // Локация
              const Text(
                'Локализация',
                style: TextStyle(color: textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 18),

              _buildDropdown(
                label: 'Ваш город',
                hint: 'Ваш город',
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Улица*',
                hint: 'Ваша улица',
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Номер дома*',
                hint: 'Номер дома',
              ),
              const SizedBox(height: 9),

              const Text(
                'Местоположение на карте',
                style: TextStyle(color: textPrimary, fontSize: 14),
              ),
              const SizedBox(height: 9),

              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: formBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.map_outlined,
                    color: textSecondary,
                    size: 40,
                  ),
                ),
              ),

              const SizedBox(height: 27),

              // Контактные данные
              const Text(
                'Ваши контактные данные',
                style: TextStyle(color: textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 18),

              _buildTextField(
                label: 'Контактное лицо*',
                hint: 'Александр',
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Электронная почта',
                hint: 'AlexAlex@mail.ru',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Номер телефона 1*',
                hint: '+7 949 456 65 56',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Номер телефона 2',
                hint: '+7 949 456 65 56',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Ссылка на ваш чат в телеграм',
                hint: 'https://t.me/username',
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Ссылка на ваш whatsapp',
                hint: 'https://wa.me/номер',
              ),

              const SizedBox(height: 32),

              _buildButton('Предпросмотр', onPressed: () {}),
              const SizedBox(height: 10),
              _buildButton(
                'Опубликовать',
                onPressed: () {},
                isPrimary: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====== Общие билдеры (повторяем стиль AddListingScreen) ======

  Widget _buildTextField({
    required String label,
    required String hint,
    int maxLines = 1,
    int minLength = 0,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: textPrimary, fontSize: 14)),
        const SizedBox(height: 9),
        TextField(
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
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

  Widget _buildDropdown({
    required String label,
    required String hint,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: textPrimary, fontSize: 14)),
        const SizedBox(height: 9),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: formBackground,
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: null,
                hint: Text(
                  hint,
                  style:
                      const TextStyle(color: textSecondary, fontSize: 14),
                ),
                icon: const Icon(Icons.keyboard_arrow_down,
                    color: textSecondary),
                items: const [],
                onChanged: (_) {
                  // тут позже можно подвязать реальные значения
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckbox({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      activeColor: activeIconColor,
      checkColor: Colors.white,
      title: Text(
        title,
        style: const TextStyle(
          color: textPrimary,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildChoiceButton(
    String text,
    bool isSelected,
    VoidCallback onPressed,
  ) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor:
              isSelected ? activeIconColor : Colors.transparent,
          side: isSelected
              ? null
              : const BorderSide(color: Colors.white),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : textPrimary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildButton(
    String text, {
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isPrimary ? activeIconColor : Colors.transparent,
          side: isPrimary
              ? null
              : const BorderSide(color: Colors.white),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(
            color: isPrimary ? Colors.white : textPrimary,
          ),
        ),
      ),
    );
  }
}
