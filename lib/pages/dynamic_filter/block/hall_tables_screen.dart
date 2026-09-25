// ============================================================
//  Столы на плане зала и их персонал (22.09.2026)
// ============================================================
//
// Макеты заказчика, путь менеджера ресторана:
//
//   «Создать сценарий бизнеса» → стрелка у зала →
//   «Настройка столов в зале»: план зала, на нём столы. Нажатие на пустое
//      место ставит стол, нажатие на стол открывает его (стол подсвечен
//      зелёным) →
//   «Настройка стола»: номер стола, мест за столом, официант, администратор →
//   «Официант столика» / «Администратор столика»: карточки сотрудников с
//      фото, «Выбрать» ↔ «Отменить», «Подтвердить» → назад к столу →
//   «Сохранить» → назад к плану → «Сохранить» → назад к сценарию.
//
// Решения заказчика:
//   - столы ресторан ставит сам на свой план (картинку зала);
//   - сотрудники берутся из справочника человека: за стол можно поставить
//     тех, кто отмечен галочкой на экране блока «Добавить сотрудника»
//     (25.09.2026);
//   - персонал свой в каждом сценарии, а стол (место, номер, число мест)
//     общий: это мебель зала;
//   - у стола есть «Мест за столом»: столы на плане заменяют поля зала
//     «Столиков на N мест» при подборе столика гостю.
//
// Ничего не отправляет: план уезжает с залом (BlockItemsService), персонал
// со сценарием (ScenariosService).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/block_item.dart';
import 'package:lidle/models/hall_table.dart';
import 'package:lidle/models/scenario.dart';
import 'package:lidle/pages/dynamic_filter/block/block_item_screen.dart';
import 'package:lidle/widgets/components/header.dart';

const Color _divider = Color(0xFF474747);
const Color _green = Color(0xFF2BD13F);
const Color _yellow = Color(0xFFE8E337);

/// Должности из поля «Должность» карточки сотрудника.
const String roleWaiter = 'Официант';
const String roleAdmin = 'Администратор';

void _soon(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(
      content: Text('Скоро будет доступно'),
      backgroundColor: secondaryBackground,
    ));
}

class _Bar extends StatelessWidget {
  const _Bar({required this.title, required this.action, required this.onAction, this.back = true});

  final String title;
  final String action;
  final VoidCallback onAction;
  final bool back;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          if (back)
            GestureDetector(
              onTap: onAction,
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
            onTap: onAction,
            child: Text(action, style: const TextStyle(color: activeIconColor, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

Widget _link(BuildContext context, String text) => GestureDetector(
      onTap: () => _soon(context),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: const TextStyle(color: activeIconColor, fontSize: 14)),
      ),
    );

Widget _button(String text, VoidCallback onTap) => SizedBox(
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

// ------------------------------------------------------------
//  «Настройка столов в зале»
// ------------------------------------------------------------

class HallTablesScreen extends StatefulWidget {
  const HallTablesScreen({
    super.key,
    required this.hall,
    required this.staff,
    required this.tableStaff,
  });

  /// Зал: его план и столы. Столы меняются только после «Сохранить».
  final BlockItemDraft hall;

  /// Сотрудники, отмеченные на экранах блока «Добавить сотрудника».
  final List<StaffRef> staff;

  /// Персонал столов этого зала в текущем сценарии (копия).
  final Map<String, TableStaff> tableStaff;

  @override
  State<HallTablesScreen> createState() => _HallTablesScreenState();
}

class _HallTablesScreenState extends State<HallTablesScreen> {
  late final List<HallTable> _tables = widget.hall.layout.map((t) => t.copy()).toList();
  late final Map<String, TableStaff> _staff = {
    for (final e in widget.tableStaff.entries) e.key: e.value.copy(),
  };
  String? _selectedKey;

  String _nextNumber() {
    var max = 0;
    for (final t in _tables) {
      final n = int.tryParse(t.number) ?? 0;
      if (n > max) max = n;
    }
    return '${max + 1}';
  }

  Future<void> _add(Offset local, Size size) async {
    final table = HallTable(
      key: HallTable.newKey(),
      x: (local.dx / size.width).clamp(0.0, 1.0),
      y: (local.dy / size.height).clamp(0.0, 1.0),
      number: _nextNumber(),
    );

    setState(() {
      _tables.add(table);
      _selectedKey = table.key;
    });

    final kept = await _open(table, isNew: true);

    // «Отмена» у нового стола: стола нет.
    if (!kept && mounted) {
      setState(() {
        _tables.remove(table);
        _selectedKey = null;
      });
    }
  }

  /// Открыть стол. Возвращает, остался ли стол на плане.
  Future<bool> _open(HallTable table, {bool isNew = false}) async {
    setState(() => _selectedKey = table.key);

    final result = await Navigator.push<_TableResult>(
      context,
      MaterialPageRoute(
        builder: (_) => TableSettingsScreen(
          table: table.copy(),
          staff: widget.staff,
          current: _staff[table.key]?.copy() ?? TableStaff(),
          isNew: isNew,
        ),
      ),
    );

    if (!mounted) return !isNew;

    if (result == null) return !isNew;

    setState(() {
      if (result.deleted) {
        _tables.remove(table);
        _staff.remove(table.key);
        _selectedKey = null;
        return;
      }

      table
        ..number = result.table.number
        ..seats = result.table.seats;

      if (result.staff.isEmpty) {
        _staff.remove(table.key);
      } else {
        _staff[table.key] = result.staff;
      }
    });

    return !result.deleted;
  }

  void _save() {
    widget.hall
      ..layout = _tables
      ..dirty = true;

    Navigator.pop(context, HallTablesResult(staff: _staff));
  }

  @override
  Widget build(BuildContext context) {
    final hall = widget.hall;
    final seats = _tables.fold<int>(0, (sum, t) => sum + t.seats);

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
                  _Bar(
                    title: 'Настройка столов в зале',
                    action: 'Отмена',
                    onAction: () => Navigator.pop(context),
                  ),
                  _link(context, 'Что такое общий план ресторана?'),
                  _link(context, 'Заказать общий план ресторана'),
                  const SizedBox(height: 6),
                  const Divider(color: _divider, height: 1),
                  const SizedBox(height: 16),
                  Text(hall.title,
                      style: const TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  AspectRatio(
                    aspectRatio: 1,
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final size = Size(box.maxWidth, box.maxHeight);

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (d) => _add(d.localPosition, size),
                          child: Stack(
                            children: [
                              Positioned.fill(child: _PlanBackground(hall: hall)),
                              for (final t in _tables)
                                Positioned(
                                  left: t.x * size.width - _TableMark.width / 2,
                                  top: t.y * size.height - _TableMark.height / 2,
                                  child: GestureDetector(
                                    onTap: () => _open(t),
                                    child: _TableMark(
                                      table: t,
                                      selected: t.key == _selectedKey,
                                      hasStaff: !(_staff[t.key]?.isEmpty ?? true),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _tables.isEmpty
                        ? 'Нажмите на свободное место плана, чтобы поставить стол. '
                            'Нажмите на стол, чтобы указать номер, места и официанта.'
                        : 'Столов: ${_tables.length}, мест: $seats. Вы добавили план зала в своем '
                            'ресторане. Теперь пользователи смогут бронировать места и выбирать '
                            'время своего визита к вам.',
                    style: const TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  _button('Сохранить', _save),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Что вернул экран плана: персонал столов в сценарии. Сами столы уже
/// записаны в зал.
class HallTablesResult {
  final Map<String, TableStaff> staff;

  const HallTablesResult({required this.staff});
}

/// План зала как фон. Нет плана — сетка, столы всё равно можно ставить.
class _PlanBackground extends StatelessWidget {
  const _PlanBackground({required this.hall});

  final BlockItemDraft hall;

  @override
  Widget build(BuildContext context) {
    if (!hall.hasFile) {
      return Container(
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _divider),
        ),
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.all(12),
        child: const Text(
          'Плана зала нет. Добавьте его на экране зала, а пока столы можно ставить на пустое поле.',
          textAlign: TextAlign.center,
          style: TextStyle(color: textMuted, fontSize: 12),
        ),
      );
    }

    if (hall.isPdf) {
      return Center(
        child: BlockFilePreview(
          localPath: hall.localFilePath,
          remoteUrl: hall.remoteFileUrl,
          kind: hall.fileKind,
        ),
      );
    }

    final image = hall.localFilePath != null
        ? Image.file(File(hall.localFilePath!), fit: BoxFit.contain)
        : Image.network(hall.remoteFileUrl!, fit: BoxFit.contain);

    return ClipRRect(borderRadius: BorderRadius.circular(6), child: image);
  }
}

/// Стол на плане: номер и число мест. Выбранный — с зелёными полосами.
class _TableMark extends StatelessWidget {
  const _TableMark({required this.table, required this.selected, required this.hasStaff});

  static const double width = 44;
  static const double height = 34;

  final HallTable table;
  final bool selected;
  final bool hasStaff;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFB9B9B9),
        borderRadius: BorderRadius.circular(5),
        border: Border.symmetric(
          vertical: BorderSide(color: selected ? _green : Colors.black, width: selected ? 4 : 2),
          horizontal: const BorderSide(color: Colors.black, width: 1),
        ),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 3)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            table.number.isEmpty ? '?' : table.number,
            style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700, height: 1),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person, size: 9, color: Colors.black87),
              Text('${table.seats}',
                  style: const TextStyle(color: Colors.black87, fontSize: 9, height: 1.2)),
              if (hasStaff) ...[
                const SizedBox(width: 2),
                const Icon(Icons.check_circle, size: 8, color: Color(0xFF1E8E2F)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
//  «Настройка стола»
// ------------------------------------------------------------

class _TableResult {
  final HallTable table;
  final TableStaff staff;
  final bool deleted;

  const _TableResult({required this.table, required this.staff, this.deleted = false});
}

class TableSettingsScreen extends StatefulWidget {
  const TableSettingsScreen({
    super.key,
    required this.table,
    required this.staff,
    required this.current,
    this.isNew = false,
  });

  final HallTable table;
  final List<StaffRef> staff;
  final TableStaff current;
  final bool isNew;

  @override
  State<TableSettingsScreen> createState() => _TableSettingsScreenState();
}

class _TableSettingsScreenState extends State<TableSettingsScreen> {
  late final TextEditingController _number = TextEditingController(text: widget.table.number);
  late int _seats = widget.table.seats;
  late final TableStaff _staff = widget.current.copy();

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _pick(String role) async {
    final isWaiter = role == roleWaiter;

    final result = await Navigator.push<_PickResult>(
      context,
      MaterialPageRoute(
        builder: (_) => StaffPickerScreen(
          title: isWaiter ? 'Официант столика' : 'Администратор столика',
          subtitle: isWaiter ? 'Выберите официанта' : 'Выберите администратора',
          role: role,
          staff: widget.staff,
          selected: isWaiter ? _staff.waiter : _staff.admin,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      if (isWaiter) {
        _staff.waiter = result.person;
      } else {
        _staff.admin = result.person;
      }
    });
  }

  void _save() {
    final number = _number.text.trim();
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Введите номер стола'),
        backgroundColor: secondaryBackground,
      ));
      return;
    }

    Navigator.pop(
      context,
      _TableResult(
        table: widget.table
          ..number = number
          ..seats = _seats,
        staff: _staff,
      ),
    );
  }

  Widget _select(String label, StaffRef? value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textPrimary, fontSize: 15)),
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
                    value == null ? 'Выбрать' : value.name,
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
                  _Bar(
                    title: 'Настройка стола',
                    action: 'Отмена',
                    onAction: () => Navigator.pop(context),
                  ),
                  _link(context, 'Что такое общий план ресторана?'),
                  const SizedBox(height: 10),
                  const Text('Номер стола', style: TextStyle(color: textPrimary, fontSize: 15)),
                  const SizedBox(height: 9),
                  Container(
                    height: 45,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: formBackground, borderRadius: BorderRadius.circular(6)),
                    child: TextField(
                      controller: _number,
                      style: const TextStyle(color: textPrimary, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Введите',
                        hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Мест за столом', style: TextStyle(color: textPrimary, fontSize: 15)),
                      ),
                      _step(Icons.remove, _seats > 1 ? () => setState(() => _seats--) : null),
                      SizedBox(
                        width: 44,
                        child: Text('$_seats',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
                      ),
                      _step(Icons.add, _seats < 30 ? () => setState(() => _seats++) : null),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _select('Официант столика', _staff.waiter, () => _pick(roleWaiter)),
                  const SizedBox(height: 18),
                  _select('Администратор столика', _staff.admin, () => _pick(roleAdmin)),
                  const SizedBox(height: 10),
                  const Text(
                    'Официант и администратор свои в каждом сценарии. Номер и места '
                    'стола общие для всех сценариев.',
                    style: TextStyle(color: textSecondary, fontSize: 12, height: 1.35),
                  ),
                  if (!widget.isNew) ...[
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: () => Navigator.pop(
                        context,
                        _TableResult(table: widget.table, staff: _staff, deleted: true),
                      ),
                      child: const Text('Удалить стол', style: TextStyle(color: Color(0xFFFF4D4D), fontSize: 14)),
                    ),
                  ],
                  const SizedBox(height: 40),
                  _button('Сохранить', _save),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(IconData icon, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: formBackground, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: onTap == null ? textMuted : textPrimary, size: 20),
        ),
      );
}

// ------------------------------------------------------------
//  «Официант столика» / «Администратор столика»
// ------------------------------------------------------------

/// Результат выбора: сотрудник или null («Отменить» у выбранного).
class _PickResult {
  final StaffRef? person;

  const _PickResult(this.person);
}

class StaffPickerScreen extends StatefulWidget {
  const StaffPickerScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.role,
    required this.staff,
    this.selected,
  });

  final String title;
  final String subtitle;
  final String role;
  final List<StaffRef> staff;
  final StaffRef? selected;

  @override
  State<StaffPickerScreen> createState() => _StaffPickerScreenState();
}

class _StaffPickerScreenState extends State<StaffPickerScreen> {
  late StaffRef? _selected = widget.selected;

  List<StaffRef> get _people =>
      widget.staff.where((s) => s.role.trim().toLowerCase() == widget.role.toLowerCase()).toList();

  @override
  Widget build(BuildContext context) {
    final people = _people;

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
                  _Bar(
                    title: widget.title,
                    action: 'Назад',
                    back: false,
                    onAction: () => Navigator.pop(context),
                  ),
                  Text(widget.subtitle, style: const TextStyle(color: textPrimary, fontSize: 16)),
                  const SizedBox(height: 12),
                  if (people.isEmpty)
                    Text(
                      'Сотрудников с должностью «${widget.role}» здесь пока нет. Откройте в форме '
                      'объявления блок «Добавить сотрудника», заведите человека с этой должностью '
                      'или поставьте ему галочку «Работает здесь».',
                      style: const TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
                    )
                  else
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.72,
                      children: [
                        for (final p in people)
                          _PersonCard(
                            person: p,
                            selected: p == _selected,
                            onTap: () => setState(() => _selected = p == _selected ? null : p),
                          ),
                      ],
                    ),
                  const SizedBox(height: 28),
                  _button('Подтвердить', () => Navigator.pop(context, _PickResult(_selected))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person, required this.selected, required this.onTap});

  final StaffRef person;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget photo;
    final url = person.imageUrl;

    if (url != null && url.isNotEmpty) {
      photo = Image.network(url, fit: BoxFit.cover);
    } else {
      photo = Container(
        color: formBackground,
        child: const Icon(Icons.person, color: textMuted, size: 48),
      );
    }

    final color = selected ? _yellow : activeIconColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(width: double.infinity, child: photo),
          ),
        ),
        const SizedBox(height: 8),
        Text(person.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: textPrimary, fontSize: 13)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 40,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color),
            ),
            child: Text(selected ? 'Отменить' : 'Выбрать', style: TextStyle(color: color, fontSize: 15)),
          ),
        ),
      ],
    );
  }
}
