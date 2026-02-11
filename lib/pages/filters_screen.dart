import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/widgets/dialogs/city_selection_dialog.dart';
import 'package:lidle/widgets/dialogs/selection_dialog.dart';

class FiltersScreen extends StatefulWidget {
  static const routeName = '/filters';

  const FiltersScreen({super.key});

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

enum DateSort { newest, oldest }

enum PriceSort { expensive, cheap }

enum AccountKind { all, private, business }

class _FiltersScreenState extends State<FiltersScreen> {
  Set<String> _selectedCity = {'Мариуполь'};
  Set<String> _selectedCategories = {}; // «Выберите категорию»
  DateSort? _dateSort = DateSort.newest;
  PriceSort? _priceSort;
  AccountKind _account = AccountKind.private;

  void _reset() async {
    setState(() {
      _selectedCity = {'Мариуполь'};
      _selectedCategories = {};
      _dateSort = DateSort.newest;
      _priceSort = null;
      _account = AccountKind.private;
    });
    await HiveService.saveSelectedCity('г. Мариуполь. ДНР');
  }

  void _submit() async {
    // Сохранить выбранный город
    if (_selectedCity.isNotEmpty) {
      await HiveService.saveSelectedCity(_selectedCity.first);
    }
    // TODO: Вернуть выбранные фильтры на предыдущий экран или применить их
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          // padding: const EdgeInsets.symmetric(horizontal: 31),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Padding(
              //   padding: const EdgeInsets.only(
              //     left: 72.0,
              //     top: 44.0,
              //     bottom: 35.0,
              //   ),
              //   child: Row(
              //     children: [SvgPicture.asset(logoAsset, height: logoHeight)],
              //   ),
              // ),

              // ШАПКА: X  |  Фильтры   |  Сбросить
              Padding(
                padding: const EdgeInsets.only(left: 25.0, right: 25.0),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        // splashRadius: 18,
                      ),
                    ),

                    const Text(
                      'Фильтры',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _reset,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF60A5FA),
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                      ),
                      child: const Text(
                        'Сбросить',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Категории + тег "Недвижимость"
              Padding(
                padding: const EdgeInsets.only(left: 25.0, right: 25.0),
                child: const Text(
                  'Категории',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 25.0, right: 25.0),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _selectedCategories
                      .map((category) => _GreyTag(text: category))
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF474747)),

              // Выбор города
              const SizedBox(height: 9),
              Padding(
                padding: const EdgeInsets.only(left: 25.0, right: 25.0),
                child: _buildDropdown(
                  label: 'Выберете город',
                  hint: _selectedCity.isEmpty
                      ? 'Ваш город'
                      : _selectedCity.join(', '),
                  icon: const Icon(
                    Icons.keyboard_arrow_right_outlined,
                    color: textSecondary,
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return CitySelectionDialog(
                          title: 'Ваш город',
                          options: const [
                            'Абаза',
                            'Абакан',
                            'Абдулино',
                            'Абинск',
                            'Агидель',
                            'Агрыз',
                            'Адыгейск',
                            'Азнакаево',
                            'Бабаево',
                            'Бабушкин Бавлы',
                            'Багратионовск',

                            // Add more cities as needed
                          ],
                          selectedOptions: _selectedCity,
                          onSelectionChanged: (Set<String> selected) {
                            setState(() {
                              _selectedCity = selected;
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Выбор категории
              Padding(
                padding: const EdgeInsets.only(left: 25.0, right: 25.0),
                child: _buildDropdown(
                  label: 'Выберите категорию',
                  hint: _selectedCategories.isEmpty
                      ? 'Выберите категорию'
                      : _selectedCategories.join(', '),
                  icon: const Icon(
                    Icons.keyboard_arrow_right_outlined,
                    color: textSecondary,
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return SelectionDialog(
                          title: 'Выберите категорию',
                          options: const [
                            'Недвижимость',
                            'Авто и мото',
                            'Работа',
                            'Подработка',
                          ],
                          selectedOptions: _selectedCategories,
                          onSelectionChanged: (Set<String> selected) {
                            setState(() {
                              _selectedCategories = selected;
                            });
                          },
                          allowMultipleSelection: true,
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Сортировка
              Padding(
                padding: const EdgeInsets.only(left: 25.0, right: 25.0),
                child: const Text(
                  'Сортировка',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 25.0, right: 25.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ChoiceButton(
                            text: 'Новые',
                            selected: _dateSort == DateSort.newest,
                            onTap: () =>
                                setState(() => _dateSort = DateSort.newest),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ChoiceButton(
                            text: 'Старое',
                            selected: _dateSort == DateSort.oldest,
                            onTap: () =>
                                setState(() => _dateSort = DateSort.oldest),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ChoiceButton(
                            text: 'Дорогие',
                            selected: _priceSort == PriceSort.expensive,
                            onTap: () => setState(
                              () => _priceSort = PriceSort.expensive,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ChoiceButton(
                            text: 'Дешевые',
                            selected: _priceSort == PriceSort.cheap,
                            onTap: () =>
                                setState(() => _priceSort = PriceSort.cheap),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFF474747)),
              // const SizedBox(height: 14),

              // Частное лицо / Бизнес
              Padding(
                padding: const EdgeInsets.only(left: 25.0, right: 25.0),
                child: const Text(
                  'Частное лицо / Бизнес',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 25.0, right: 25.0),
                child: Row(
                  children: [
                    Flexible(
                      flex: 1,
                      child: _ToggleButton(
                        text: 'Все',
                        selected: _account == AccountKind.all,
                        onTap: () => setState(() => _account = AccountKind.all),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      flex: 2,
                      child: _ToggleButton(
                        text: 'Частное лицо',
                        selected: _account == AccountKind.private,
                        onTap: () =>
                            setState(() => _account = AccountKind.private),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      flex: 2,
                      child: _ToggleButton(
                        text: 'Бизнес',
                        selected: _account == AccountKind.business,
                        onTap: () =>
                            setState(() => _account = AccountKind.business),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // Кнопка "Показать" на низу
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          25,
          0,
          25,
          43 + MediaQuery.of(context).padding.bottom,
        ),
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: activeIconColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Text('Показать'),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String hint,
    VoidCallback? onTap,
    String? subtitle,
    Widget? icon,
    bool showChangeText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textPrimary, fontSize: 16)),
        const SizedBox(height: 9),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: subtitle != null ? 60 : 45,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              color: formBackground,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: subtitle != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              hint,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color.fromARGB(255, 255, 255, 255),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: Color(0xFF7A7A7A),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          hint,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color.fromARGB(255, 255, 255, 255),
                            fontSize: 14,
                          ),
                        ),
                ),
                if (showChangeText)
                  Text(
                    'Изменить',
                    style: TextStyle(
                      color: Colors.blue, // Синий цвет
                      fontSize: 14, // Размер 14
                    ),
                  ),
                if (icon != null) icon,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/* ========================= helpers ========================= */

class _GreyTag extends StatelessWidget {
  final String text;
  const _GreyTag({required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 129,
      height: 35,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF868686),
          borderRadius: BorderRadius.circular(5),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(color: Color(0xFF232E3C), fontSize: 14),
        ),
      ),
    );
  }
}

// class _PickField extends StatelessWidget {
//   final String label;
//   final VoidCallback onTap;
//   const _PickField({required this.label, required this.onTap});

//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(8),
//       child: Container(
//         height: 48,
//         decoration: BoxDecoration(
//           color: secondaryBackground,
//           borderRadius: BorderRadius.circular(8),
//         ),
//         padding: const EdgeInsets.symmetric(horizontal: 14),
//         child: Row(
//           children: [
//             Expanded(
//               child: Text(
//                 label,
//                 style: const TextStyle(color: Colors.white70, fontSize: 14),
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ),
//             const Icon(Icons.chevron_right, color: Colors.white60),
//           ],
//         ),
//       ),
//     );
//   }
// }

class _ChoiceButton extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? activeIconColor : Colors.transparent;
    final fg = selected ? Colors.white : Colors.white70;
    final border = selected
        ? Border.all(color: Colors.transparent)
        : Border.all(color: const Color(0x80FFFFFF));

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 35,
        // padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(5),
          border: border,
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: fg,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ChoiceButton(text: text, selected: selected, onTap: onTap);
  }
}
