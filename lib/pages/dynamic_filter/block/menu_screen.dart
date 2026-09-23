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
import 'package:lidle/pages/dynamic_filter/block/block_fields_form.dart';
import 'package:lidle/widgets/components/header.dart';

const Color _divider = Color(0xFF474747);
const Color _red = Color(0xFFFF4D4D);

/// Описание длиннее этого, если человек его вообще заполнил.
const int _descriptionMin = 70;

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
  });

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

  late final MenuContent _menu = widget.initial?.menu.copy() ?? MenuContent();
  late final TextEditingController _groupName = TextEditingController();

  String? _selectedGroup;

  @override
  void initState() {
    super.initState();

    final initial = widget.initial;
    if (initial != null) _controller.prefill(initial.values);

    if (_menu.groups.isNotEmpty) {
      _selectedGroup = _menu.groups.first.key;
      _groupName.text = _menu.groups.first.name;
    }
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

    setState(() {
      _menu.groups.add(group);
      _select(group);
    });
  }

  Future<void> _changeGroupImage(MenuGroup group) async {
    final path = await pickMenuImage(context);
    if (path == null || !mounted) return;

    setState(() {
      group.localPath = path;
      group.imageUrl = null;
      group.image = null;
    });
  }

  Future<void> _openItem([MenuItem? item]) async {
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
          groups: _menu.groups,
          cuisines: _cuisines,
          isNew: item == null,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _menu.items.removeWhere((i) => i.key == result.item.key);
      if (!result.deleted) _menu.items.add(result.item);
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
                  const _Links(),
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
                  SizedBox(
                    height: 96,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final g in _menu.groups)
                          _GroupCard(
                            group: g,
                            selected: g.key == group?.key,
                            onTap: () => _select(g),
                            onEdit: () => _changeGroupImage(g),
                          ),
                        // Плюс ровно того же размера, что карточки групп.
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: _addGroup,
                              child: Container(
                                width: 96,
                                height: 70,
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
                            const SizedBox(width: 96, child: Text(' ', style: TextStyle(fontSize: 13))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    group == null
                        ? 'Добавьте группу, например «Завтраки», и положите в неё блюда.'
                        : 'Содержимое группы: ${group.name}',
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (group != null)
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.72,
                      children: [
                        for (final dish in dishes)
                          _DishCard(dish: dish, onEdit: () => _openItem(dish)),
                        GestureDetector(
                          onTap: () => _openItem(),
                          child: Container(
                            decoration: BoxDecoration(
                              color: formBackground,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_outline, color: textSecondary, size: 30),
                                SizedBox(height: 8),
                                Text('Добавить позицию',
                                    style: TextStyle(color: textSecondary, fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
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
  const _Links();

  @override
  Widget build(BuildContext context) {
    Widget link(String text) => GestureDetector(
          onTap: () => _say(context, 'Скоро будет доступно'),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(text, style: const TextStyle(color: activeIconColor, fontSize: 14)),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [link('Как это работает?'), link('Что такое группы?')],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 96,
              height: 70,
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
                    height: 70,
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
          SizedBox(
            width: 96,
            child: Text(
              group.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? textPrimary : textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DishCard extends StatelessWidget {
  const _DishCard({required this.dish, required this.onEdit});

  final MenuItem dish;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: MenuPhoto(
            localPath: dish.localPath,
            url: dish.imageUrl,
            height: double.infinity,
            hint: '',
            onTap: onEdit,
          ),
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
        Text('Цена: ${dish.price} ₽',
            style: const TextStyle(color: textSecondary, fontSize: 12)),
        if (dish.weight > 0)
          Text('Вес: ${dish.weight} г',
              style: const TextStyle(color: textSecondary, fontSize: 12)),
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
    this.isNew = false,
  });

  final MenuItem item;
  final List<MenuGroup> groups;
  final List<String> cuisines;
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
      _say(context, 'Введите название позиции');
      return;
    }

    if (price <= 0) {
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
      builder: (_) => const _DeleteDialog(),
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
                    title: 'Добавить позицию',
                    onBack: () => Navigator.pop(context),
                    onCancel: () => Navigator.pop(context),
                  ),
                  _label('Изображение позиции'),
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
                  _label('Название позиции'),
                  const SizedBox(height: 9),
                  _field(controller: _name),
                  const SizedBox(height: 16),
                  _select('Выбор группы', _groupName(_group), _pickGroup),
                  const SizedBox(height: 16),
                  _select(
                    'Вид кухни блюда',
                    _cuisines.join(', '),
                    widget.cuisines.isEmpty ? () {} : _pickCuisines,
                  ),
                  const SizedBox(height: 16),
                  _label('Номер позиции'),
                  const SizedBox(height: 9),
                  _field(controller: _position, keyboard: TextInputType.number),
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
                  const SizedBox(height: 16),
                  _label('Вес (г.)'),
                  const SizedBox(height: 9),
                  _field(controller: _weight, keyboard: TextInputType.number),
                  const SizedBox(height: 16),
                  _label('Описание позиции'),
                  const SizedBox(height: 9),
                  _field(
                    controller: _description,
                    maxLines: 5,
                    hint: 'Чем больше информации вы укажете о вашем блюде, тем более '
                        'привлекательнее оно будет для клиентов. Без ссылок, телефонов, '
                        'матерных слов.',
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
                        child: const Text('Удалить товар',
                            style: TextStyle(color: _red, fontSize: 16)),
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

/// Окно «Удалить товар».
class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: secondaryBackground,
      title: const Text('Удалить товар',
          style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Внимание: ',
                  style: TextStyle(color: Color(0xFFE8E337), fontSize: 14),
                ),
                TextSpan(
                  text: 'позиция пропадёт из меню.',
                  style: TextStyle(color: textPrimary, fontSize: 14),
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          Text('Подтвердите действие', style: TextStyle(color: textSecondary, fontSize: 13)),
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
