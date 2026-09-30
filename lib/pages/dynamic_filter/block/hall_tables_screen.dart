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
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/block_item.dart';
import 'package:lidle/models/hall_table.dart';
import 'package:lidle/models/scenario.dart';
import 'package:lidle/pages/dynamic_filter/block/block_item_screen.dart';
import 'package:lidle/widgets/bookings/hall_table_mark.dart';
import 'package:lidle/widgets/components/header.dart';

const Color _divider = Color(0xFF474747);
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
          // Зал и соседние столы нужны превью: рамку подгоняют не на
          // пустом квадрате, а на своём плане (30.09.2026).
          hall: widget.hall,
          others: [
            for (final t in _tables)
              if (t.key != table.key) t.copy(),
          ],
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
        ..seats = result.table.seats
        // Депозит и «Важно!» тоже общие для всех сценариев: это свойства
        // самого стола, а не смены (29.09.2026).
        ..deposit = result.table.deposit
        ..note = result.table.note
        ..w = result.table.w
        ..h = result.table.h
        ..angle = result.table.angle
        // Положение тоже общее свойство стола: его двигают ползунками в
        // настройке (30.09.2026).
        ..x = result.table.x
        ..y = result.table.y;

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

                              // Метки те же, что увидит гость (30.09.2026):
                              // продавец подгоняет рамку под свой стол и
                              // сразу видит результат, а не догадывается.
                              ...tableMarkLayers(
                                plan: size,
                                spots: [
                                  for (final t in _tables)
                                    TableSpot(
                                      key: t.key,
                                      number: t.number,
                                      seats: t.seats,
                                      x: t.x,
                                      y: t.y,
                                      width: t.w,
                                      height: t.h,
                                      angle: t.angle,
                                      state: t.key == _selectedKey
                                          ? TableMarkState.selected
                                          : TableMarkState.free,
                                      hasStaff: !(_staff[t.key]?.isEmpty ?? true),
                                    ),
                                ],
                                onTap: (spot) {
                                  final table = _tables.firstWhere((t) => t.key == spot.key);

                                  _open(table);
                                },
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
                        : 'Столов: ${_tables.length}, мест: $seats. Нажмите на стол, чтобы задать '
                            'номер, места, а также размер и поворот рамки: она должна лечь ровно '
                            'на ваш стол на плане. Так же схему увидит гость.',
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

/// Распознаватель жеста, который не уступает прокрутке (30.09.2026).
///
/// Внутри списка обычный жест масштабирования проигрывает: прокрутка ловит
/// движение раньше, и рамку нельзя было бы двигать вверх и вниз. Этот берёт
/// касание себе, как карта внутри страницы.
class _EagerScale extends ScaleGestureRecognizer {
  @override
  void rejectGesture(int pointer) => acceptGesture(pointer);
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
    required this.hall,
    this.isNew = false,
    this.others = const [],
  });

  final HallTable table;
  final List<StaffRef> staff;
  final TableStaff current;
  final bool isNew;

  /// Зал: из него берётся картинка плана для превью.
  final BlockItemDraft hall;

  /// Остальные столы зала: в превью они видны приглушёнными, чтобы рамка не
  /// налезла на соседний стол.
  final List<HallTable> others;

  @override
  State<TableSettingsScreen> createState() => _TableSettingsScreenState();
}

class _TableSettingsScreenState extends State<TableSettingsScreen> {
  late final TextEditingController _number = TextEditingController(text: widget.table.number);
  late int _seats = widget.table.seats;
  late final TableStaff _staff = widget.current.copy();

  /// Депозит за стол и примечание к нему (29.09.2026). Ноль в поле не
  /// показываем: пустое поле честнее говорит «депозита нет».
  late final TextEditingController _deposit =
      TextEditingController(text: widget.table.deposit > 0 ? '${widget.table.deposit}' : '');

  late final TextEditingController _note = TextEditingController(text: widget.table.note);

  /// Размер рамки долями плана и её поворот (30.09.2026). Столы на схемах
  /// разные: длинный на восемь человек и круглый на двоих, да ещё под углом.
  late double _w = widget.table.w.clamp(kTableMarkMin, kTableMarkMax);
  late double _h = widget.table.h.clamp(kTableMarkMin, kTableMarkMax);
  late double _angle = (widget.table.angle % 360).clamp(0.0, 355.0);

  /// Где стол стоит на плане, долями сторон (30.09.2026). Раньше положение
  /// задавалось один раз, нажатием на план, и подвинуть стол было нельзя:
  /// поставил чуть мимо — удаляй и ставь заново.
  late double _x = widget.table.x.clamp(0.0, 1.0);
  late double _y = widget.table.y.clamp(0.0, 1.0);

  /// Середина окна превью, долями плана (30.09.2026). Отдельно от положения
  /// стола: рамку тянут пальцем, и план под ней должен стоять на месте, иначе
  /// палец идёт вправо, а картинка уезжает влево — рука не понимает, что
  /// происходит. Окно подъезжает, только когда рамка подходит к его краю.
  late double _viewX = _x;
  late double _viewY = _y;

  /// Сторона окна превью в точках. Нужна ползункам: они тоже двигают рамку и
  /// тоже должны подтягивать окно.
  double _side = 300;

  /// Размер и поворот на начало жеста двумя пальцами.
  double _startW = 0;
  double _startH = 0;
  double _startAngle = 0;

  /// Сколько пальцев было на прошлом шаге жеста. Если второй палец убрали и
  /// снова поставили, распознаватель начинает масштаб заново, и без этого
  /// счётчика размер прыгнул бы к тому, что был в начале жеста.
  int _fingers = 0;

  /// Насколько приблизить план в превью. Считается ОДИН раз, при открытии
  /// стола: если пересчитывать от текущего размера, приближение будет его
  /// компенсировать, и ползунок перестанет увеличивать рамку — вместо неё
  /// станет отъезжать план. Оставляем запас, чтобы рамке было куда расти.
  ///
  /// План в PDF не приближаем: он рисуется своим просмотрщиком с
  /// ограничением по высоте, и метки уехали бы мимо страницы.
  late final double _zoom = widget.hall.isPdf
      ? 1.0
      : (0.4 / math.max(widget.table.w, widget.table.h)).clamp(1.0, 3.0);

  @override
  void dispose() {
    _number.dispose();
    _deposit.dispose();
    _note.dispose();
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
          ..seats = _seats
          ..deposit = int.tryParse(_deposit.text.trim()) ?? 0
          ..note = _note.text.trim()
          ..w = _w
          ..h = _h
          ..angle = _angle
          ..x = _x
          ..y = _y,
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
                  const SizedBox(height: 22),
                  const Text('Рамка стола на плане', style: TextStyle(color: textPrimary, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text(
                    'Подгоните рамку под ваш стол на схеме: ширину, высоту и поворот. '
                    'Ровно так стол увидит гость, а цветом рамки ему будет видно, '
                    'свободен он или занят.',
                    style: TextStyle(color: textSecondary, fontSize: 12, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  _preview(),
                  const SizedBox(height: 12),
                  _slider('Ширина', _w, kTableMarkMin, _maxSide,
                      (v) => setState(() => _w = v)),
                  _slider('Высота', _h, kTableMarkMin, _maxSide,
                      (v) => setState(() => _h = v)),
                  _slider('Поворот', _angle, 0.0, 355.0, (v) => setState(() => _angle = v),
                      divisions: 71, suffix: '°'),

                  // Положение без делений: стол двигают до точного совпадения
                  // с картинкой, и шаг в полпроцента тут мешал бы.
                  _slider('Влево-вправо', _x, 0.0, 1.0, (v) {
                    setState(() {
                      _x = v;
                      _follow();
                    });
                  }, divisions: null),
                  _slider('Вверх-вниз', _y, 0.0, 1.0, (v) {
                    setState(() {
                      _y = v;
                      _follow();
                    });
                  }, divisions: null),
                  const SizedBox(height: 18),
                  const Text('Депозит за стол, ₽', style: TextStyle(color: textPrimary, fontSize: 15)),
                  const SizedBox(height: 9),
                  Container(
                    height: 45,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: formBackground, borderRadius: BorderRadius.circular(6)),
                    child: TextField(
                      controller: _deposit,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: textPrimary, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Без депозита',
                        hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Депозит входит в счёт гостя. Свой у каждого стола: у окна '
                    'можно поставить больше, чем у прохода.',
                    style: TextStyle(color: textSecondary, fontSize: 12, height: 1.35),
                  ),
                  const SizedBox(height: 18),
                  const Text('Важно знать о столе', style: TextStyle(color: textPrimary, fontSize: 15)),
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: formBackground, borderRadius: BorderRadius.circular(6)),
                    child: TextField(
                      controller: _note,
                      maxLines: 3,
                      maxLength: 300,
                      style: const TextStyle(color: textPrimary, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Например: объединяется только со столом № 5',
                        hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
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

  /// Наибольший размер рамки. Ограничен не только общим потолком, но и
  /// окном превью: рамка вдвое шире окна не даёт увидеть, что подгоняешь.
  double get _maxSide => math.min(kTableMarkMax, 0.95 / _zoom);

  /// Начало жеста: запоминаем, от чего считать размер и поворот.
  void _scaleStart() {
    _startW = _w;
    _startH = _h;
    _startAngle = _angle;
    _fingers = 1;
  }

  /// Шаг жеста. Один палец двигает рамку, два меняют размер и поворот.
  void _scaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      if (d.pointerCount > 1) {
        // Второй палец только что вернулся — считаем от нынешнего размера.
        if (_fingers < 2) {
          _startW = _w;
          _startH = _h;
          _startAngle = _angle;
        }

        _w = (_startW * d.scale).clamp(kTableMarkMin, _maxSide);
        _h = (_startH * d.scale).clamp(kTableMarkMin, _maxSide);

        final turned = _startAngle + d.rotation * 180 / math.pi;

        _angle = (turned % 360 + 360) % 360;

        // Ползунок кончается на 355. Дальше по кругу к нулю, а не упор:
        // под пальцем рамка не должна застревать.
        if (_angle > 355) _angle = 0;
      }

      _fingers = d.pointerCount;

      _move(d.focalPointDelta.dx, d.focalPointDelta.dy);
    });
  }

  /// Подвинуть рамку и подтянуть окно, если она ушла к краю.
  void _move(double dx, double dy) {
    final plan = _side * _zoom;

    _x = (_x + dx / plan).clamp(0.0, 1.0);
    _y = (_y + dy / plan).clamp(0.0, 1.0);

    _follow();
  }

  /// Окно едет за рамкой, но не при каждом движении: пока рамка внутри
  /// середины окна, план стоит. Так картинка не дёргается под пальцем.
  void _follow() {
    // Мёртвая зона — треть полуокна, в долях плана.
    final margin = 0.32 / _zoom;

    if (_x - _viewX > margin) _viewX = _x - margin;
    if (_viewX - _x > margin) _viewX = _x + margin;
    if (_y - _viewY > margin) _viewY = _y - margin;
    if (_viewY - _y > margin) _viewY = _y + margin;

    _viewX = _viewX.clamp(0.0, 1.0);
    _viewY = _viewY.clamp(0.0, 1.0);
  }

  /// Как рамка ляжет на план: кусок настоящей схемы вокруг этого стола,
  /// приближённый (30.09.2026).
  ///
  /// На пустом квадрате подогнать размер нельзя: не с чем сравнить, и рамка
  /// получается то мелкой, то во весь зал. Поэтому здесь тот же план, что на
  /// схеме, только увеличенный и сдвинутый так, чтобы этот стол был в
  /// середине. Соседние столы показаны приглушённо: видно, не налезла ли
  /// рамка на чужой стол.
  Widget _preview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              decoration: BoxDecoration(
                color: formBackground,
                border: Border.all(color: _divider),
                borderRadius: BorderRadius.circular(6),
              ),
              child: LayoutBuilder(
                builder: (context, box) {
                  final side = box.maxWidth;
                  final plan = side * _zoom;

                  // Сторона нужна ползункам, которые двигают рамку вне этого
                  // метода. Запись без setState: перерисовку она не просит.
                  _side = side;

                  // Окно стоит на месте, пока рамка не подошла к его краю: у
                  // края плана оно упирается в край схемы, а не уезжает в
                  // пустоту.
                  final left = (side / 2 - _viewX * plan).clamp(side - plan, 0.0);
                  final top = (side / 2 - _viewY * plan).clamp(side - plan, 0.0);

                  // Номер меняется прямо во время набора: иначе кажется, что
                  // поле не сработало.
                  return AnimatedBuilder(
                    animation: _number,
                    // Один палец двигает рамку, два меняют размер и поворот
                    // (30.09.2026). Жест забираем себе раньше списка: обычный
                    // GestureDetector отдал бы вертикальное движение прокрутке
                    // экрана, и рамку нельзя было бы двигать вверх и вниз.
                    // Плата за это — по самому превью список не прокручивается,
                    // как и по карте: для прокрутки есть всё, что выше и ниже.
                    builder: (context, _) => RawGestureDetector(
                      behavior: HitTestBehavior.opaque,
                      gestures: {
                        _EagerScale:
                            GestureRecognizerFactoryWithHandlers<_EagerScale>(
                          () => _EagerScale(),
                          // Обычный блок, а не каскад со стрелкой: каскад
                          // прилипает к телу лямбды и присваивается её
                          // результату.
                          (r) {
                            r.onStart = (_) => _scaleStart();
                            r.onUpdate = _scaleUpdate;
                          },
                        ),
                      },
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Positioned(
                            left: left,
                            top: top,
                            width: plan,
                            height: plan,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                    child: _PlanBackground(hall: widget.hall)),
                                ...tableMarkLayers(
                                  plan: Size(plan, plan),
                                  spots: [
                                    for (final other in widget.others)
                                      TableSpot(
                                        key: other.key,
                                        number: other.number,
                                        seats: other.seats,
                                        x: other.x,
                                        y: other.y,
                                        width: other.w,
                                        height: other.h,
                                        angle: other.angle,
                                        state: TableMarkState.unknown,
                                      ),
                                    TableSpot(
                                      key: widget.table.key,
                                      number: _number.text.trim(),
                                      seats: _seats,
                                      x: _x,
                                      y: _y,
                                      width: _w,
                                      height: _h,
                                      angle: _angle,
                                      state: TableMarkState.selected,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _zoom > 1.05
              ? 'Ваш план, приближен ×${_zoom.toStringAsFixed(1)}. Зелёная рамка — этот стол.'
              : 'Ваш план целиком. Зелёная рамка — этот стол.',
          style: const TextStyle(color: textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    int? divisions = 56,
    String suffix = '%',
  }) {
    final shown = suffix == '%' ? (value * 100).round() : value.round();

    return Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(label, style: const TextStyle(color: textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: activeIconColor,
              inactiveTrackColor: _divider,
              thumbColor: activeIconColor,
              overlayShape: SliderComponentShape.noOverlay,
              trackHeight: 3,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 46,
          child: Text(
            '$shown$suffix',
            textAlign: TextAlign.right,
            style: const TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
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
