// ============================================================
//  Меню ресторана: группы и позиции (23.09.2026)
// ============================================================
//
// Макеты заказчика:
//
//   «Добавить меню» — название меню, название выбранной группы, полоса
//      групп с картинками и плюсом, ниже «Содержимое группы: …» с
//      карточками блюд и плиткой «Добавить позицию», «Сохранить»;
//   «Добавить группу» — окно с картинкой и названием, «Отмена» и «Готово»;
//   «Добавить позицию» — картинка, название, группа, вид кухни, номер
//      позиции, цена, вес, описание, «Сохранить», а при правке ещё
//      «Удалить товар» с подтверждением.
//
// Меню у ресторана может быть несколько: основное, барное, банкетное. Внутри
// каждого свои группы, внутри групп блюда.
//
// Ничего не отправляет: меню уезжает вместе с объявлением, картинки групп и
// блюд уходят файлами в том же запросе (BlockItemsService).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/block_item.dart';
import 'package:lidle/models/filter_models.dart';
import 'package:lidle/models/menu_content.dart';
import 'package:lidle/models/products/product_staff.dart';
import 'package:lidle/pages/dynamic_filter/block/block_fields_form.dart';
import 'package:lidle/pages/products/add_product/product_staff_member_screen.dart';
import 'package:lidle/services/deliveries_service.dart';
import 'package:lidle/services/staff_service.dart';
import 'package:lidle/widgets/components/header.dart';

const Color _divider = Color(0xFF474747);
const Color _red = Color(0xFFFF4D4D);

/// Описание длиннее этого, если человек его вообще заполнил.
const int _descriptionMin = 70;

/// Чем блок отличается от блока (23.09.2026).
///
/// Экран один на меню, товары, услуги и всё, что описывается группами и
/// позициями. Разница между ними мелкая: у блюда вес и вид кухни, у товара
/// количество штук, у услуги ни того, ни другого — только цена.
class GroupedBlockConfig {
  /// Подпись поля количества: «Вес (г.)» или «Колл. (шт.)». Пусто — поля нет
  /// вовсе (услуги, 23.09.2026).
  final String? amountLabel;

  /// Как это количество показать в карточке: «Вес: 300 г», «шт: 7».
  final String amountShort;

  /// Единица после числа в карточке.
  final String amountUnit;

  /// Показывать ли «Вид кухни блюда».
  final bool showCuisine;

  /// Что именно добавляют: «блюдо», «товар», «услугу». Идёт в кнопку
  /// «Удалить …» и в подсказки.
  final String itemWord;

  /// То же во множественном числе: «блюда», «товары», «услуги».
  final String itemsWord;

  /// Пример группы в подсказке пустого экрана.
  final String groupExample;

  /// Подсказка в поле «Описание позиции».
  final String descriptionHint;

  /// Текст окна «Как это работает?».
  final String howItWorks;

  /// Текст окна «Что такое группы?».
  final String whatAreGroups;

  /// Как подписать цену в карточке: «Цена: 755 ₽», «Стоимость: от 400 ₽».
  final String priceLabel;

  /// Общий справочник человека (23.09.2026): группы и позиции живут не в
  /// объявлении, а у человека, и видны во всех его категориях. Здесь своя
  /// только цена. Так работают доставка и сотрудники.
  final bool directory;

  /// Справочник сотрудников, а не доставки (25.09.2026).
  ///
  /// Отличий два: ходим на свои ручки (`/me/staff`) и вместо цены у позиции
  /// галочка «работает здесь» и должность.
  final bool staff;

  /// Подпись поля должности вместо цены (25.09.2026).
  final String? roleLabel;

  /// Пропорции карточки в сетке. У сотрудника под картинкой на две строки
  /// больше (должность и галочка), поэтому карточка выше (25.09.2026).
  final double cardAspect;

  /// Высота карточки числом вместо пропорций, и высота картинки внутри неё
  /// (25.09.2026).
  ///
  /// У сотрудников картинка ростом с фотографию на паспорт: квадратная по
  /// ширине ячейки, она занимала пол-экрана, и список из четырёх человек
  /// приходилось листать. Пусто — высота считается из пропорций, как было.
  final double? cardHeight;

  final double? photoHeight;

  const GroupedBlockConfig({
    required this.amountShort,
    required this.amountUnit,
    required this.itemWord,
    required this.itemsWord,
    required this.groupExample,
    required this.descriptionHint,
    required this.howItWorks,
    required this.whatAreGroups,
    this.priceLabel = 'Цена',
    this.directory = false,
    this.staff = false,
    this.roleLabel,
    this.cardAspect = 0.72,
    this.cardHeight,
    this.photoHeight,
    this.amountLabel,
    this.showCuisine = false,
  });

  static const GroupedBlockConfig menu = GroupedBlockConfig(
    amountLabel: 'Вес (г.)',
    amountShort: 'Вес',
    amountUnit: 'г',
    showCuisine: true,
    itemWord: 'блюдо',
    itemsWord: 'блюда',
    groupExample: '«Завтраки»',
    descriptionHint: 'Чем больше информации вы укажете о вашем блюде, тем более '
        'привлекательнее оно будет для клиентов. Без ссылок, телефонов, '
        'матерных слов.',
    howItWorks: 'Меню состоит из групп, а в группах лежат блюда. Добавьте группу, '
        'например «Завтраки», и положите в неё блюда: фото, название, цену, вес '
        'и описание.\n\nМеню можно добавить несколько: основное, барное, '
        'банкетное. Гость увидит их в карточке заведения.',
    whatAreGroups: 'Группа — это раздел меню: «Завтраки», «Салаты», «Напитки». '
        'Внутри группы блюда идут по номеру позиции, а сами группы по номеру '
        'группы, так что порядок вы задаёте сами.',
  );

  static const GroupedBlockConfig products = GroupedBlockConfig(
    amountLabel: 'Колл. (шт.)',
    amountShort: 'шт',
    amountUnit: '',
    itemWord: 'товар',
    itemsWord: 'товары',
    groupExample: '«Цветы»',
    descriptionHint: 'Чем больше информации вы укажете о вашем товаре, тем более '
        'привлекательнее он будет для клиентов. Без ссылок, телефонов, '
        'матерных слов.',
    howItWorks: 'Товары лежат в группах. Добавьте группу, например «Цветы», и '
        'положите в неё товары: фото, название, цену, количество и описание.\n\n'
        'Списков товаров можно добавить несколько, гость увидит их в карточке.',
    whatAreGroups: 'Группа — это раздел списка: «Цветы», «Подарки», «Открытки». '
        'Внутри группы товары идут по номеру позиции, а сами группы по номеру '
        'группы, так что порядок вы задаёте сами.',
  );

  /// Услуги (23.09.2026): ни веса, ни количества, только цена.
  static const GroupedBlockConfig services = GroupedBlockConfig(
    amountShort: '',
    amountUnit: '',
    itemWord: 'услугу',
    itemsWord: 'услуги',
    groupExample: '«День рождения»',
    descriptionHint: 'Чем больше информации вы укажете о вашей услуге, тем более '
        'привлекательнее она будет для клиентов. Без ссылок, телефонов, '
        'матерных слов.',
    howItWorks: 'Услуги лежат в группах. Добавьте группу, например «День рождения», '
        'и положите в неё услуги: фото, название, цену и описание.\n\nГость '
        'увидит их в карточке заведения и сможет заказать вместе с бронью.',
    whatAreGroups: 'Группа — это повод или направление: «День рождения», «Свадьбы», '
        '«Корпоративы». Внутри группы услуги идут по номеру позиции, а сами '
        'группы по номеру группы, так что порядок вы задаёте сами.',
  );

  /// Доставка (23.09.2026): общая у человека, цена своя у каждого места.
  static const GroupedBlockConfig delivery = GroupedBlockConfig(
    amountShort: '',
    amountUnit: '',
    itemWord: 'доставку',
    itemsWord: 'способы доставки',
    groupExample: '«Доставка»',
    priceLabel: 'Стоимость: от',
    directory: true,
    descriptionHint: 'Опишите, как вы доставляете: по каким районам, за какое '
        'время, от какой суммы заказа. Без ссылок, телефонов, матерных слов.',
    howItWorks: 'Доставка у вас одна на все ваши объявления и товары: завели '
        'курьера здесь — он появится и в остальных, заводить заново не нужно.'
        '\n\nЦена своя у каждого места: «Доставка на авто» может стоить 400 ₽ '
        'в ресторане и 600 ₽ в цветочном. Пока цена не поставлена, покупателю '
        'этот способ не показывается.',
    whatAreGroups: 'Группа — это способ доставки или район: «Доставка», «По '
        'городу», «За город». Группы и способы общие для всех ваших '
        'объявлений, поэтому и удаление убирает их везде.',
  );

  /// Сотрудники (25.09.2026): общие у человека, а галочка своя у заведения.
  static const GroupedBlockConfig staffDirectory = GroupedBlockConfig(
    amountShort: '',
    amountUnit: '',
    itemWord: 'сотрудника',
    itemsWord: 'сотрудников',
    groupExample: '«Официанты»',
    directory: true,
    staff: true,
    roleLabel: 'Должность',
    cardAspect: 0.6,
    cardHeight: 250,
    photoHeight: 159,
    descriptionHint: 'Расскажите о сотруднике: что делает, чем помогает гостю. '
        'Без ссылок, телефонов, матерных слов.',
    howItWorks: 'Сотрудники у вас одни на все ваши объявления и товары: завели '
        'официанта здесь — он появится и в остальных, заводить заново не нужно.'
        '\n\nГалочка отмечает, кто работает именно в этом заведении. Без '
        'галочки человек остаётся в вашем списке, но гостю здесь не '
        'показывается и за стол его не поставить.\n\nГрафик, зарплату, '
        'контакты и доступы сотрудника можно заполнить на его карточке в '
        'разделе товаров: список один и тот же.',
    whatAreGroups: 'Группа — это отдел или смена: «Официанты», «Повара», '
        '«Администраторы». Группы и сотрудники общие для всех ваших '
        'объявлений, поэтому и удаление убирает их везде. Чтобы убрать '
        'человека только из этого заведения, снимите галочку.',
  );
}

Widget _barRow({
  required String title,
  required VoidCallback onBack,
  required VoidCallback onCancel,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.arrow_back_ios_new, color: textPrimary, size: 18),
          ),
        ),
        Expanded(
          child: Text(title,
              style: const TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        ),
        GestureDetector(
          onTap: onCancel,
          child: const Text('Отмена', style: TextStyle(color: activeIconColor, fontSize: 15)),
        ),
      ],
    ),
  );
}

Widget _blueButton(String text, VoidCallback onTap) => SizedBox(
      height: 46,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: activeIconColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
    );

Widget _label(String text) =>
    Text(text, style: const TextStyle(color: textPrimary, fontSize: 15));

Widget _field({
  required TextEditingController controller,
  String hint = 'Введите',
  TextInputType? keyboard,
  int maxLines = 1,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(color: formBackground, borderRadius: BorderRadius.circular(6)),
    child: TextField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: const TextStyle(color: textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    ),
  );
}

void _say(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), backgroundColor: secondaryBackground));
}

/// Выбор картинки: галерея или камера. PDF у меню не нужен.
Future<String?> pickMenuImage(BuildContext context) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: secondaryBackground,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in const [
            ['gallery', 'Фото из галереи', Icons.photo_library_outlined],
            ['camera', 'Сделать фото', Icons.photo_camera_outlined],
          ])
            ListTile(
              leading: Icon(entry[2] as IconData, color: activeIconColor),
              title: Text(entry[1] as String, style: const TextStyle(color: textPrimary)),
              onTap: () => Navigator.pop(context, entry[0] as String),
            ),
        ],
      ),
    ),
  );

  if (choice == null) return null;

  final picked = await ImagePicker().pickImage(
    source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 2000,
    imageQuality: 90,
  );

  final path = picked?.path;
  if (path == null) return null;

  if (await File(path).length() > 20 * 1024 * 1024) {
    if (context.mounted) _say(context, 'Файл больше 20 МБ');
    return null;
  }

  return path;
}

/// Картинка группы или блюда: с телефона, с сервера или плюс.
class MenuPhoto extends StatelessWidget {
  const MenuPhoto({
    super.key,
    this.localPath,
    this.url,
    this.height = 120,
    this.hint = 'Добавить изображение',
    this.onTap,
  });

  final String? localPath;
  final String? url;
  final double height;
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget child;

    if (localPath != null) {
      child = Image.file(File(localPath!), fit: BoxFit.cover);
    } else if (url != null && url!.isNotEmpty) {
      child = Image.network(url!, fit: BoxFit.cover);
    } else {
      child = Container(
        color: formBackground,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: textSecondary, width: 1.5),
              ),
              child: const Icon(Icons.add, color: textSecondary, size: 24),
            ),
            const SizedBox(height: 8),
            Text(hint, style: const TextStyle(color: textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(width: double.infinity, height: height, child: child),
      ),
    );
  }
}

// ------------------------------------------------------------
//  «Добавить меню»
// ------------------------------------------------------------

class MenuScreen extends StatefulWidget {
  const MenuScreen({
    super.key,
    required this.block,
    required this.fields,
    this.initial,
    this.advertId,
    this.config = GroupedBlockConfig.menu,
  });

  /// Объявление, которое сейчас правят: его собственные экраны в списке
  /// «Взять из другого объявления» не нужны (23.09.2026).
  final int? advertId;

  final GroupedBlockConfig config;

  final Attribute block;

  /// Поля блока: «Название меню» и «Вид кухни блюда» (её варианты нужны
  /// экрану позиции).
  final List<Attribute> fields;

  final BlockItemDraft? initial;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  late final List<Attribute> _nameFields =
      widget.fields.where((f) => f.style == 'H').toList();

  late final BlockFieldsController _controller = BlockFieldsController(_nameFields);

  /// Варианты «Вида кухни блюда» из админки.
  late final List<String> _cuisines = [
    for (final f in widget.fields)
      if (f.style == 'F')
        for (final v in f.values) v.value,
  ];

  MenuContent _menu = MenuContent();
  late final TextEditingController _groupName = TextEditingController();

  String? _selectedGroup;

  /// Справочник ещё едет с сервера (только у доставки).
  bool _loading = false;

  /// Должности для выбора. Экран блока их не грузит: карточку сотрудника
  /// открывает свой экран, и список он берёт сам (25.09.2026). Поле осталось
  /// для остальных блоков, у которых должности не бывает вовсе.
  final List<String> _positions = const [];

  @override
  void initState() {
    super.initState();

    _menu = widget.initial?.menu.copy() ?? MenuContent();

    final initial = widget.initial;
    if (initial != null) _controller.prefill(initial.values);

    _selectFirst();

    // Доставка общая у человека: список групп и курьеров приезжает из его
    // справочника, а не из объявления (23.09.2026). Цены при этом свои у
    // этого экрана, они уже лежат в ответе.
    if (widget.config.directory) _reload();

    // Должности здесь не нужны: карточку сотрудника открывает свой экран,
    // и список он грузит сам (25.09.2026).
  }

  void _selectFirst() {
    if (_menu.groups.isEmpty) {
      _selectedGroup = null;
      _groupName.text = '';

      return;
    }

    final first = _menu.sortedGroups.first;
    _selectedGroup = first.key;
    _groupName.text = first.name;
  }

  // ── Справочник человека ─────────────────────────────────────────
  // Доставка и сотрудники устроены одинаково, но ходят на свои ручки, и у
  // доставки своя у места цена, а у сотрудника галочка (25.09.2026).

  bool get _isStaff => widget.config.staff;

  Future<MenuContent?> _loadDirectory() => _isStaff
      ? StaffService.load(widget.initial?.serverId)
      : DeliveriesService.load(widget.initial?.serverId);

  String _groupKeyOf(int id) =>
      _isStaff ? StaffService.groupKey(id) : DeliveriesService.groupKey(id);

  String _itemKeyOf(int id) =>
      _isStaff ? StaffService.memberKey(id) : DeliveriesService.optionKey(id);

  Future<int?> _createDirectoryGroup(String name, {String? imagePath}) => _isStaff
      ? StaffService.createGroup(name, imagePath: imagePath)
      : DeliveriesService.createGroup(name, imagePath: imagePath);

  Future<bool> _updateDirectoryGroup(int id, String name, {String? imagePath}) => _isStaff
      ? StaffService.updateGroup(id, name, imagePath: imagePath)
      : DeliveriesService.updateGroup(id, name, imagePath: imagePath);

  Future<bool> _deleteDirectoryGroup(int id) =>
      _isStaff ? StaffService.deleteGroup(id) : DeliveriesService.deleteGroup(id);

  Future<int?> _createDirectoryItem(MenuItem item, int? groupId) => _isStaff
      ? StaffService.createMember(
          name: item.name,
          role: item.role,
          description: item.description,
          groupId: groupId,
          imagePath: item.localPath,

          // Место здесь не отмечаем: галочки экрана уезжают полем `content`
          // вместе с объявлением, и второй источник истины разошёлся бы с
          // первым — снятую галочку пришлось бы снимать дважды (25.09.2026).
        )
      : DeliveriesService.createOption(
          name: item.name,
          description: item.description,
          groupId: groupId,
          imagePath: item.localPath,
        );

  Future<bool> _updateDirectoryItem(MenuItem item, int? groupId) => _isStaff
      ? StaffService.updateMember(
          id: _idOf(item.key),
          name: item.name,
          role: item.role,
          description: item.description,
          groupId: groupId,
          imagePath: item.localPath,
        )
      : DeliveriesService.updateOption(
          id: _idOf(item.key),
          name: item.name,
          description: item.description,
          groupId: groupId,
          imagePath: item.localPath,
        );

  Future<bool> _deleteDirectoryItem(int id) =>
      _isStaff ? StaffService.deleteMember(id) : DeliveriesService.deleteOption(id);

  /// Перечитать справочник с сервера, сохранив уже введённые цены и галочки.
  Future<void> _reload() async {
    setState(() => _loading = true);

    final loaded = await _loadDirectory();

    if (!mounted) return;

    // Справочник не приехал: оставляем то, что на экране уже есть. Иначе
    // обрыв связи стёр бы цены и галочки, и «Сохранить» отправило бы пустоту
    // (25.09.2026).
    if (loaded == null) {
      setState(() => _loading = false);

      _say(context, 'Справочник не загрузился, проверьте связь');

      return;
    }

    // Цена и галочка живут в этом экране: то, что человек только что поставил,
    // важнее сохранённого. У нового объявления экрана на сервере ещё нет, и с
    // сервера они приходят пустыми.
    for (final item in loaded.items) {
      final local = _menu.items.where((i) => i.key == item.key);
      if (local.isEmpty) continue;

      if (local.first.price > 0) item.price = local.first.price;

      // Галочку берём свою целиком: снятая тоже решение человека, а не
      // «ничего не ставил».
      item.selected = local.first.selected;
    }

    setState(() {
      final selected = _selectedGroup;
      _menu = loaded;
      _loading = false;

      if (selected != null && _menu.groups.any((g) => g.key == selected)) {
        _selectedGroup = selected;
        _groupName.text = _group?.name ?? '';
      } else {
        _selectFirst();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _groupName.dispose();
    super.dispose();
  }

  MenuGroup? get _group {
    for (final g in _menu.groups) {
      if (g.key == _selectedGroup) return g;
    }
    return null;
  }

  void _select(MenuGroup group) {
    setState(() {
      _selectedGroup = group.key;
      _groupName.text = group.name;
    });
  }

  Future<void> _addGroup() async {
    final group = await showDialog<MenuGroup>(
      context: context,
      builder: (_) => const _GroupDialog(),
    );

    if (group == null || !mounted) return;

    if (widget.config.directory) {
      final id = await _createDirectoryGroup(group.name, imagePath: group.localPath);

      if (!mounted) return;

      if (id == null) {
        _say(context, 'Не удалось сохранить группу');

        return;
      }

      await _reload();

      if (mounted) {
        final saved = _menu.groups.where((g) => g.key == _groupKeyOf(id));
        if (saved.isNotEmpty) _select(saved.first);
      }

      return;
    }

    setState(() {
      group.position = _menu.groups.length + 1;
      _menu.groups.add(group);
      _select(group);
    });
  }

  /// Номер строки справочника из ключа: «g12» → 12, «o7» → 7.
  int _idOf(String key) => int.tryParse(key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  /// «Настроить группу»: картинка, название, номер, удаление (23.09.2026).
  Future<void> _editGroup(MenuGroup group) async {
    // Папка «без группы» появляется сама и на сервере её нет: править нечего
    // (25.09.2026).
    if (widget.config.directory && _idOf(group.key) == 0) {
      _say(
        context,
        _isStaff
            ? 'Это все, кто не в группе. Чтобы собрать их в папку, добавьте группу'
            : 'Это всё, что не в группе. Чтобы собрать их в папку, добавьте группу',
      );

      return;
    }

    final result = await Navigator.push<_GroupResult>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupSettingsScreen(
          group: group.copy(),
          directory: widget.config.directory,
        ),
      ),
    );

    if (result == null || !mounted) return;

    if (widget.config.directory) {
      final id = _idOf(group.key);

      final ok = result.deleted
          ? await _deleteDirectoryGroup(id)
          : await _updateDirectoryGroup(
              id,
              result.group.name,
              imagePath: result.group.localPath,
            );

      if (!mounted) return;

      if (!ok) {
        _say(context, 'Не удалось сохранить');

        return;
      }

      await _reload();

      return;
    }

    setState(() {
      if (result.deleted) {
        _menu.groups.removeWhere((g) => g.key == group.key);
        _menu.items.removeWhere((i) => i.group == group.key);
        final first = _menu.groups.isEmpty ? null : _menu.sortedGroups.first;
        _selectedGroup = first?.key;
        _groupName.text = first?.name ?? '';
        return;
      }

      group
        ..name = result.group.name
        ..position = result.group.position
        ..localPath = result.group.localPath
        ..imageUrl = result.group.imageUrl
        ..image = result.group.image;

      if (group.key == _selectedGroup) _groupName.text = group.name;
    });
  }

  Future<void> _openItem([MenuItem? item]) async {
    // У сотрудника карточка своя и полная: зарплата, график, доступы,
    // контакты. Это тот же экран, что в товарах, справочник-то общий
    // (25.09.2026).
    if (_isStaff) {
      await _openStaffMember(item);

      return;
    }

    final group = _group;
    if (group == null) {
      _say(context, 'Сначала добавьте группу');
      return;
    }

    final result = await Navigator.push<_ItemResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MenuItemScreen(
          item: item?.copy() ??
              MenuItem(
                key: MenuContent.newKey('d'),
                group: group.key,
                position: _menu.ofGroup(group.key).length + 1,
              ),
          groups: _menu.sortedGroups,
          cuisines: _cuisines,
          positions: _positions,
          isNew: item == null,
          config: widget.config,
        ),
      ),
    );

    if (result == null || !mounted) return;

    // Способ доставки и сотрудник общие: сами они живут в справочнике
    // человека, а здесь остаётся только своё — цена или галочка (23.09.2026).
    if (widget.config.directory) {
      final saved = result.item;
      final groupId = _idOf(saved.group);
      final price = saved.price;

      if (result.deleted) {
        if (!await _deleteDirectoryItem(_idOf(saved.key))) {
          if (mounted) _say(context, 'Не удалось удалить');

          return;
        }
      } else if (item == null) {
        final id = await _createDirectoryItem(saved, groupId > 0 ? groupId : null);

        if (id == null) {
          if (mounted) _say(context, 'Не удалось сохранить');

          return;
        }

        // Цену и галочку держим у себя до сохранения объявления: место для них
        // это экран блока, а его до этого ещё нет. Заведённый здесь сотрудник
        // сразу отмечен: иначе человек добавил бы его и не увидел в заведении.
        _menu.items.add(MenuItem(
          key: _itemKeyOf(id),
          group: saved.group,
          name: saved.name,
          description: saved.description,
          role: saved.role,
          selected: _isStaff,
          price: price,
        ));
      } else {
        final ok = await _updateDirectoryItem(saved, groupId > 0 ? groupId : null);

        if (!ok) {
          if (mounted) _say(context, 'Не удалось сохранить');

          return;
        }

        final old = _menu.items.where((i) => i.key == saved.key);
        if (old.isNotEmpty) old.first.price = price;
      }

      await _reload();

      return;
    }

    setState(() {
      _menu.items.removeWhere((i) => i.key == result.item.key);
      if (!result.deleted) _menu.items.add(result.item);
    });
  }

  /// Плитка «Добавить …» в конце сетки.
  Widget _addTile() {
    return GestureDetector(
      onTap: () => _openItem(),
      child: Container(
        height: widget.config.photoHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline, color: textSecondary, size: 30),
            const SizedBox(height: 8),
            Text(
              widget.config.staff ? 'Добавить сотрудника' : 'Добавить позицию',
              textAlign: TextAlign.center,
              style: const TextStyle(color: textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  /// Карточка сотрудника: тот же экран, что в разделе товаров (25.09.2026).
  ///
  /// Сохраняет он сам, прямо в справочник человека, поэтому после возврата
  /// экран перечитывает список. Заведённый здесь сразу отмечается галочкой:
  /// иначе человек добавил бы сотрудника и не увидел его в заведении.
  Future<void> _openStaffMember(MenuItem? item) async {
    setState(() => _loading = true);

    final directory = await StaffService.directory(blockItemId: widget.initial?.serverId);

    if (!mounted) return;

    setState(() => _loading = false);

    if (directory == null) {
      _say(context, 'Справочник не загрузился, проверьте связь');

      return;
    }

    final people = <StaffMember>[
      ...directory.ungrouped,
      for (final group in directory.groups) ...group.members,
    ];

    StaffMember? existing;

    if (item != null) {
      final id = _idOf(item.key);

      for (final person in people) {
        if (person.id == id) {
          existing = person;

          break;
        }
      }

      if (existing == null) {
        _say(context, 'Сотрудник не найден, обновите список');

        return;
      }
    }

    // Новый попадает в открытую сейчас группу, а из папки «Без группы» —
    // тоже без группы.
    final open = _group;
    final openId = open == null ? 0 : _idOf(open.key);

    // Кто был в справочнике до этого. Берём из только что прочитанного
    // справочника, а не с экрана: экран мог не успеть загрузиться, и тогда
    // «новыми» оказались бы все (25.09.2026).
    final before = people.map((person) => person.id).toSet();

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductStaffMemberScreen(
          groups: directory.groups,
          existing: existing,
          groupId: existing?.groupId ?? (openId > 0 ? openId : null),
        ),
      ),
    );

    if (saved != true || !mounted) return;

    await _reload();

    if (!mounted || item != null) return;

    setState(() {
      for (final person in _menu.items) {
        if (!before.contains(_idOf(person.key))) person.selected = true;
      }
    });
  }

  void _save() {
    // Название группы правится прямо на экране.
    final group = _group;
    if (group != null) group.name = _groupName.text.trim();

    final missing = _controller.missingRequired();
    if (missing.isNotEmpty) {
      _say(context, 'Заполните: ${missing.join(', ')}');
      return;
    }

    if (_menu.groups.any((g) => g.name.isEmpty)) {
      _say(context, 'У каждой группы должно быть название');
      return;
    }

    final draft = widget.initial ?? BlockItemDraft();
    draft
      ..values = _controller.payload()
      ..summary = _controller.summary()
      ..menu = _menu
      ..dirty = true;

    Navigator.pop(context, draft);
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final dishes = group == null ? <MenuItem>[] : _menu.ofGroup(group.key);

    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            const Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(25, 8, 25, 30),
                children: [
                  _barRow(
                    title: widget.block.title,
                    onBack: () => Navigator.pop(context),
                    onCancel: () => Navigator.pop(context),
                  ),
                  _Links(config: widget.config),

                  const SizedBox(height: 10),
                  const Divider(color: _divider, height: 1),
                  const SizedBox(height: 18),
                  BlockFieldsForm(controller: _controller),
                  _label('Название группы'),
                  const SizedBox(height: 9),
                  // Групп ещё нет: нажатие по полю открывает то же окно, что
                  // и плюс. Иначе непонятно, куда нажимать первым (23.09.2026).
                  group == null
                      ? GestureDetector(
                          onTap: _addGroup,
                          child: Container(
                            height: 45,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: formBackground,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Добавьте первую группу',
                              style: TextStyle(color: textSecondary, fontSize: 14),
                            ),
                          ),
                        )
                      : _field(controller: _groupName),
                  const SizedBox(height: 14),
                  // Высота полосы по содержимому, а не заданная числом: при
                  // коротких названиях фиксированные 132 оставляли пустую
                  // полосу перед «Содержимым группы» (23.09.2026).
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        for (final g in _menu.sortedGroups)
                          _GroupCard(
                            group: g,
                            selected: g.key == group?.key,
                            onTap: () => _select(g),
                            onEdit: () => _editGroup(g),
                          ),
                        // Плюс ровно того же размера, что карточки групп.
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: _addGroup,
                              child: Container(
                                width: 116,
                                height: 88,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: formBackground,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.transparent, width: 1.5),
                                ),
                                child: const Icon(Icons.add_circle_outline, color: textSecondary),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const SizedBox(width: 116, child: Text(' ', style: TextStyle(fontSize: 11))),
                          ],
                        ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  // Справочник общий и едет с сервера: пока он в пути, видно,
                  // что экран занят, а не пуст (25.09.2026).
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('Обновляем список…',
                          style: TextStyle(color: textSecondary, fontSize: 12)),
                    ),
                  Text(
                    group != null
                        ? 'Содержимое группы: ${group.name}'
                        : widget.config.staff
                            // Сотрудника можно завести и без группы: он ляжет
                            // в «Без группы» (25.09.2026).
                            ? 'Добавьте сотрудника. Группы, например '
                                '${widget.config.groupExample}, нужны, чтобы '
                                'их было удобнее искать.'
                            : 'Добавьте группу, например ${widget.config.groupExample}, '
                                'и положите в неё ${widget.config.itemsWord}.',
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // У сотрудников плитка «Добавить сотрудника» нужна и когда
                  // групп ещё нет: человека можно завести и без группы, он
                  // ляжет в «Без группы» (25.09.2026).
                  if (group != null || widget.config.staff)
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 16,
                        childAspectRatio: widget.config.cardAspect,

                        // Задана высота — она главнее пропорций: карточка
                        // сотрудника одинаковая на любом экране (25.09.2026).
                        mainAxisExtent: widget.config.cardHeight,
                      ),
                      children: [
                        for (final dish in dishes)
                          _DishCard(
                            dish: dish,
                            config: widget.config,
                            onEdit: () => _openItem(dish),
                            onToggle: widget.config.staff
                                ? () => setState(() => dish.selected = !dish.selected)
                                : null,
                          ),
                        // Ячейка сетки задаёт высоту жёстко. У блоков без
                        // заданной высоты плитка занимает ячейку целиком, как
                        // и было, а у сотрудников прижимается к верху и стоит
                        // ровно с фотографию рядом (25.09.2026).
                        if (widget.config.photoHeight == null)
                          _addTile()
                        else
                          Align(alignment: Alignment.topCenter, child: _addTile()),
                      ],
                    ),
                  const SizedBox(height: 26),
                  _blueButton('Сохранить', _save),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Links extends StatelessWidget {
  const _Links({required this.config});

  final GroupedBlockConfig config;

  @override
  Widget build(BuildContext context) {
    Widget link(String text, String body) => GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: secondaryBackground,
              title: Text(
                text,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SingleChildScrollView(
                child: Text(
                  body,
                  style: const TextStyle(color: textPrimary, fontSize: 14, height: 1.4),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Понятно', style: TextStyle(color: activeIconColor)),
                ),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(text, style: const TextStyle(color: activeIconColor, fontSize: 14)),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        link('Как это работает?', config.howItWorks),
        link('Что такое группы?', config.whatAreGroups),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.selected,
    required this.onTap,
    required this.onEdit,
  });

  final MenuGroup group;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 116,
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected ? activeIconColor : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MenuPhoto(
                    localPath: group.localPath,
                    url: group.imageUrl,
                    height: 88,
                    hint: '',
                    onTap: onTap,
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: GestureDetector(
                      onTap: onEdit,
                      child: const Icon(Icons.edit, color: activeIconColor, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Название целиком, в две строки: «Доставка самокатом» обрезалось
          // до «Доставка са…», а на товарном экране видно полностью
          // (23.09.2026).
          SizedBox(
            width: 116,
            child: Text(
              group.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? textPrimary : textSecondary,
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DishCard extends StatelessWidget {
  const _DishCard({
    required this.dish,
    required this.onEdit,
    required this.config,
    this.onToggle,
  });

  final MenuItem dish;
  final GroupedBlockConfig config;
  final VoidCallback onEdit;

  /// Галочка «работает здесь» у сотрудника (25.09.2026).
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final photo = config.photoHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photo == null)
          Expanded(
            child: MenuPhoto(
              localPath: dish.localPath,
              url: dish.imageUrl,
              height: double.infinity,
              hint: '',
              onTap: onEdit,
            ),
          )
        else
          MenuPhoto(
            localPath: dish.localPath,
            url: dish.imageUrl,
            height: photo,
            hint: '',
            onTap: onEdit,
          ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                dish.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: textPrimary, fontSize: 13),
              ),
            ),
            GestureDetector(
              onTap: onEdit,
              child: const Icon(Icons.edit, color: activeIconColor, size: 16),
            ),
          ],
        ),
        if (config.staff && dish.role.isNotEmpty)
          Text(dish.role, style: const TextStyle(color: textSecondary, fontSize: 12)),
        if (onToggle != null)
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Icon(
                    dish.selected ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 18,
                    color: dish.selected ? activeIconColor : textSecondary,
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Работает здесь',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!config.staff && dish.price > 0)
          Text('${config.priceLabel} ${dish.price} ₽',
              style: const TextStyle(color: textSecondary, fontSize: 12)),
        if (dish.weight > 0 && config.amountShort.isNotEmpty)
          Text(
            '${config.amountShort}: ${dish.weight}${config.amountUnit.isEmpty ? '' : ' ${config.amountUnit}'}',
            style: const TextStyle(color: textSecondary, fontSize: 12),
          ),
      ],
    );
  }
}

/// Окно «Добавить группу».
class _GroupDialog extends StatefulWidget {
  const _GroupDialog();

  @override
  State<_GroupDialog> createState() => _GroupDialogState();
}

class _GroupDialogState extends State<_GroupDialog> {
  final TextEditingController _name = TextEditingController();
  String? _path;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: secondaryBackground,
      title: const Text('Добавить группу',
          style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Изображение группы'),
          const SizedBox(height: 8),
          MenuPhoto(
            localPath: _path,
            onTap: () async {
              final path = await pickMenuImage(context);
              if (path != null && mounted) setState(() => _path = path);
            },
          ),
          const SizedBox(height: 14),
          _label('Название группы'),
          const SizedBox(height: 8),
          _field(controller: _name),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена', style: TextStyle(color: textPrimary)),
        ),
        TextButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) {
              _say(context, 'Введите название группы');
              return;
            }

            Navigator.pop(
              context,
              MenuGroup(key: MenuContent.newKey('g'), name: name, localPath: _path),
            );
          },
          child: const Text('Готово', style: TextStyle(color: activeIconColor)),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
//  «Настроить группу»
// ------------------------------------------------------------

class _GroupResult {
  final MenuGroup group;
  final bool deleted;

  const _GroupResult({required this.group, this.deleted = false});
}

/// Правка группы по карандашу: картинка, название, номер и удаление
/// (23.09.2026). Удаление уносит и позиции этой группы.
class GroupSettingsScreen extends StatefulWidget {
  const GroupSettingsScreen({super.key, required this.group, this.directory = false});

  final MenuGroup group;

  /// Группа из общего справочника человека: удаление уберёт её везде.
  final bool directory;

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  late final TextEditingController _name = TextEditingController(text: widget.group.name);
  late final TextEditingController _position =
      TextEditingController(text: '${widget.group.position}');

  late String? _localPath = widget.group.localPath;
  late String? _imageUrl = widget.group.imageUrl;

  @override
  void dispose() {
    _name.dispose();
    _position.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();

    if (name.isEmpty) {
      _say(context, 'Введите название группы');
      return;
    }

    final group = widget.group
      ..name = name
      ..position = int.tryParse(_position.text.trim()) ?? 1
      ..localPath = _localPath
      ..imageUrl = _imageUrl;

    if (_localPath != null) group.image = null;

    Navigator.pop(context, _GroupResult(group: group));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(
        what: 'группу',
        warning: widget.directory
            ? 'группа общая, она пропадёт во всех ваших объявлениях и товарах.'
            : 'группа и её позиции пропадут.',
      ),
    );

    if (ok == true && mounted) {
      Navigator.pop(context, _GroupResult(group: widget.group, deleted: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            const Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(25, 8, 25, 30),
                children: [
                  _barRow(
                    title: 'Настроить группу',
                    onBack: () => Navigator.pop(context),
                    onCancel: () => Navigator.pop(context),
                  ),
                  _label('Изображение группы'),
                  const SizedBox(height: 9),
                  MenuPhoto(
                    localPath: _localPath,
                    url: _imageUrl,
                    height: 150,
                    onTap: () async {
                      final path = await pickMenuImage(context);
                      if (path != null && mounted) {
                        setState(() {
                          _localPath = path;
                          _imageUrl = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _label('Название группы'),
                  const SizedBox(height: 9),
                  _field(controller: _name),
                  const SizedBox(height: 16),
                  _label('Номер позиции группы'),
                  const SizedBox(height: 9),
                  _field(controller: _position, keyboard: TextInputType.number),
                  const SizedBox(height: 26),
                  SizedBox(
                    height: 46,
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _delete,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Удалить группу',
                          style: TextStyle(color: _red, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _blueButton('Сохранить', _save),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
//  «Добавить позицию»
// ------------------------------------------------------------

class _ItemResult {
  final MenuItem item;
  final bool deleted;

  const _ItemResult({required this.item, this.deleted = false});
}

class MenuItemScreen extends StatefulWidget {
  const MenuItemScreen({
    super.key,
    required this.item,
    required this.groups,
    required this.cuisines,
    this.positions = const [],
    this.isNew = false,
    this.config = GroupedBlockConfig.menu,
  });

  final GroupedBlockConfig config;

  final MenuItem item;
  final List<MenuGroup> groups;
  final List<String> cuisines;

  /// Должности для выбора у сотрудника (25.09.2026). Пусто — справочник не
  /// заведён, и должность вписывают руками.
  final List<String> positions;

  final bool isNew;

  @override
  State<MenuItemScreen> createState() => _MenuItemScreenState();
}

class _MenuItemScreenState extends State<MenuItemScreen> {
  late final TextEditingController _name = TextEditingController(text: widget.item.name);
  late final TextEditingController _price =
      TextEditingController(text: widget.item.price > 0 ? '${widget.item.price}' : '');
  late final TextEditingController _weight =
      TextEditingController(text: widget.item.weight > 0 ? '${widget.item.weight}' : '');
  late final TextEditingController _description =
      TextEditingController(text: widget.item.description);
  late final TextEditingController _position =
      TextEditingController(text: '${widget.item.position}');

  /// Должность сотрудника (25.09.2026). У остальных блоков поля нет.
  late final TextEditingController _role = TextEditingController(text: widget.item.role);

  late String _group = widget.item.group;
  late List<String> _cuisines = List.of(widget.item.cuisines);
  late String? _localPath = widget.item.localPath;
  late String? _imageUrl = widget.item.imageUrl;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _weight.dispose();
    _description.dispose();
    _position.dispose();
    _role.dispose();
    super.dispose();
  }

  String _groupName(String key) {
    for (final g in widget.groups) {
      if (g.key == key) return g.name;
    }
    return 'Выбрать';
  }

  Future<void> _pickGroup() async {
    final key = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: secondaryBackground,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final g in widget.groups)
              ListTile(
                title: Text(g.name, style: const TextStyle(color: textPrimary)),
                trailing: g.key == _group
                    ? const Icon(Icons.check, color: activeIconColor)
                    : null,
                onTap: () => Navigator.pop(context, g.key),
              ),
          ],
        ),
      ),
    );

    if (key != null && mounted) setState(() => _group = key);
  }

  /// Выбрать должность из общего списка (25.09.2026).
  Future<void> _pickRole() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: secondaryBackground,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final position in widget.positions)
                ListTile(
                  title: Text(position, style: const TextStyle(color: textPrimary)),
                  trailing: position == _role.text.trim()
                      ? const Icon(Icons.check, color: activeIconColor)
                      : null,
                  onTap: () => Navigator.pop(context, position),
                ),
            ],
          ),
        ),
      ),
    );

    if (chosen != null && mounted) setState(() => _role.text = chosen);
  }

  Future<void> _pickCuisines() async {
    final chosen = await showDialog<List<String>>(
      context: context,
      builder: (_) => _CuisineDialog(options: widget.cuisines, selected: _cuisines),
    );

    if (chosen != null && mounted) setState(() => _cuisines = chosen);
  }

  void _save() {
    final name = _name.text.trim();
    final price = int.tryParse(_price.text.trim()) ?? 0;
    final description = _description.text.trim();

    if (name.isEmpty) {
      _say(context, widget.config.staff ? 'Введите имя сотрудника' : 'Введите название позиции');
      return;
    }

    if (widget.config.staff && _role.text.trim().isEmpty) {
      _say(context, 'Укажите должность: по ней сотрудника ставят за стол');
      return;
    }

    if (price <= 0 && !widget.config.directory) {
      _say(context, 'Введите цену позиции');
      return;
    }

    if (description.isNotEmpty && description.length < _descriptionMin) {
      _say(context, 'Описание не короче $_descriptionMin символов');
      return;
    }

    final item = widget.item
      ..name = name
      ..group = _group
      ..cuisines = _cuisines
      ..price = price
      ..weight = int.tryParse(_weight.text.trim()) ?? 0
      ..role = _role.text.trim()
      ..description = description
      ..position = int.tryParse(_position.text.trim()) ?? 1
      ..localPath = _localPath
      ..imageUrl = _imageUrl;

    if (_localPath != null) item.image = null;

    Navigator.pop(context, _ItemResult(item: item));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(
        what: widget.config.itemWord,
        warning: widget.config.staff
            ? 'сотрудник общий, он пропадёт во всех ваших объявлениях и товарах. '
                'Чтобы убрать его только отсюда, снимите галочку.'
            : widget.config.directory
                ? 'этот способ общий, он пропадёт во всех ваших объявлениях и товарах.'
                : 'позиция пропадёт из списка.',
      ),
    );

    if (ok == true && mounted) {
      Navigator.pop(context, _ItemResult(item: widget.item, deleted: true));
    }
  }

  Widget _select(String label, String value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 9),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: formBackground, borderRadius: BorderRadius.circular(6)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value.isEmpty ? 'Выбрать' : value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: textPrimary, fontSize: 14),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            const Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(25, 8, 25, 30),
                children: [
                  _barRow(
                    title: widget.config.staff ? 'Добавить сотрудника' : 'Добавить позицию',
                    onBack: () => Navigator.pop(context),
                    onCancel: () => Navigator.pop(context),
                  ),
                  _label(widget.config.staff ? 'Фото сотрудника' : 'Изображение позиции'),
                  const SizedBox(height: 9),
                  MenuPhoto(
                    localPath: _localPath,
                    url: _imageUrl,
                    height: 160,
                    onTap: () async {
                      final path = await pickMenuImage(context);
                      if (path != null && mounted) {
                        setState(() {
                          _localPath = path;
                          _imageUrl = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _label(widget.config.staff ? 'Имя сотрудника' : 'Название позиции'),
                  const SizedBox(height: 9),
                  _field(controller: _name),
                  const SizedBox(height: 16),
                  _select('Выбор группы', _groupName(_group), _pickGroup),
                  if (widget.config.showCuisine) ...[
                    const SizedBox(height: 16),
                    _select(
                      'Вид кухни блюда',
                      _cuisines.join(', '),
                      widget.cuisines.isEmpty ? () {} : _pickCuisines,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _label('Номер позиции'),
                  const SizedBox(height: 9),
                  _field(controller: _position, keyboard: TextInputType.number),
                  // У сотрудника вместо цены должность: по ней экран стола
                  // отбирает официантов и администраторов (25.09.2026).
                  if (widget.config.staff) ...[
                    const SizedBox(height: 16),
                    // Список должностей ведёт администратор: «Официант» и
                    // «Администратор» должны писаться одинаково, по ним
                    // настройка столов и находит людей. Справочника нет —
                    // вписывают руками (25.09.2026).
                    if (widget.positions.isEmpty) ...[
                      _label(widget.config.roleLabel ?? 'Должность'),
                      const SizedBox(height: 9),
                      _field(controller: _role, hint: 'Официант, Администратор, Повар'),
                    ] else
                      _select(
                        widget.config.roleLabel ?? 'Должность',
                        _role.text,
                        _pickRole,
                      ),
                    const SizedBox(height: 6),
                    const Text(
                      'За стол можно поставить только «Официанта» и «Администратора»: '
                      'так их находит настройка столов.',
                      style: TextStyle(color: textSecondary, fontSize: 12, height: 1.35),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    _label('Цена позиции'),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(child: _field(controller: _price, keyboard: TextInputType.number)),
                        const SizedBox(width: 8),
                        Container(
                          width: 48,
                          height: 45,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: formBackground,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('₽', style: TextStyle(color: textPrimary, fontSize: 16)),
                        ),
                      ],
                    ),
                  ],
                  if (widget.config.amountLabel != null) ...[
                    const SizedBox(height: 16),
                    _label(widget.config.amountLabel!),
                    const SizedBox(height: 9),
                    _field(controller: _weight, keyboard: TextInputType.number),
                  ],
                  const SizedBox(height: 16),
                  _label(widget.config.staff ? 'Описание сотрудника' : 'Описание позиции'),
                  const SizedBox(height: 9),
                  _field(
                    controller: _description,
                    maxLines: 5,
                    hint: widget.config.descriptionHint,
                  ),
                  const SizedBox(height: 6),
                  const Text('Если заполняете описание, то не короче 70 символов',
                      style: TextStyle(color: textSecondary, fontSize: 12)),
                  const SizedBox(height: 22),
                  if (!widget.isNew) ...[
                    SizedBox(
                      height: 46,
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _delete,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: Text('Удалить ${widget.config.itemWord}',
                            style: const TextStyle(color: _red, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _blueButton('Сохранить', _save),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Окно «Вид кухни блюда»: несколько галочек.
class _CuisineDialog extends StatefulWidget {
  const _CuisineDialog({required this.options, required this.selected});

  final List<String> options;
  final List<String> selected;

  @override
  State<_CuisineDialog> createState() => _CuisineDialogState();
}

class _CuisineDialogState extends State<_CuisineDialog> {
  late final Set<String> _chosen = widget.selected.toSet();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: secondaryBackground,
      title: const Text('Вид кухни блюда',
          style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in widget.options)
              GestureDetector(
                onTap: () => setState(() {
                  _chosen.contains(option) ? _chosen.remove(option) : _chosen.add(option);
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(option, style: const TextStyle(color: textPrimary, fontSize: 15)),
                      ),
                      Icon(
                        _chosen.contains(option)
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: _chosen.contains(option) ? activeIconColor : textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена', style: TextStyle(color: textPrimary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _chosen.toList()),
          child: const Text('Готово', style: TextStyle(color: activeIconColor)),
        ),
      ],
    );
  }
}

/// Окно «Удалить товар» и «Удалить группу».
class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.what, required this.warning});

  final String what;
  final String warning;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: secondaryBackground,
      title: Text('Удалить $what',
          style: const TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Внимание: ',
                  style: TextStyle(color: Color(0xFFE8E337), fontSize: 14),
                ),
                TextSpan(
                  text: warning,
                  style: const TextStyle(color: textPrimary, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text('Подтвердите действие', style: TextStyle(color: textSecondary, fontSize: 13)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена', style: TextStyle(color: textPrimary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Подтвердить', style: TextStyle(color: activeIconColor)),
        ),
      ],
    );
  }
}
