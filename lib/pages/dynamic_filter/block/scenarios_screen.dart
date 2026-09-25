// ============================================================
//  Сценарии бизнеса, «Таблица распределения» (22.09.2026)
// ============================================================
//
// Идея Саши (созвон, 12:38–16:54): заведение один раз добавляет залы, меню,
// товары, услуги, доставку, сотрудников и оплату, а потом собирает из них
// сценарии. «В зале 1 и 3 завтраки, с доставкой, оплата картой» — чтобы не
// составлять кучу меню: один раз настроил, и всё работает.
//
// Экраны по макетам:
//   список    — карточки «Сценарий 1»: по строке на блок и номера
//               отмеченного («Залы 1 | 2 | 3»), «Изменить», «Удалить»;
//               «Создать сценарий», «Сохранить»;
//   создание  — строки блоков, в строке квадраты 1, 2, 3 … по числу
//               добавленного в блок. Серый — пустое место (в блок ещё ничего
//               не добавлено), белый — есть, зелёный — отмечен в сценарии.
//               Стрелка рядом показывает, что это за зал (меню, …);
//   правка    — то же и поле «Название сценария»;
//   удаление  — окно «Удалить сценарий» с подтверждением.
//
// Строки — блоки «Добавить …» этой же формы, в том же порядке. Номер в
// квадрате — порядковый номер в блоке, как человек его добавлял.
//
// Ничего не отправляет: список уезжает с объявлением (ScenariosService).

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/block_item.dart';
import 'package:lidle/models/scenario.dart';
import 'package:lidle/pages/dynamic_filter/block/hall_tables_screen.dart';
import 'package:lidle/widgets/components/header.dart';

const Color _divider = Color(0xFF474747);
const Color _green = Color(0xFF2BD13F);
const Color _red = Color(0xFFFF4D4D);
const Color _tileBg = Color(0xFF17212B);

/// Строка таблицы: блок «Добавить …» и то, что в него добавлено.
class ScenarioRow {
  final int blockId;
  final String label;
  final List<BlockItemDraft> items;

  const ScenarioRow({required this.blockId, required this.label, required this.items});
}

/// «Добавить общий план зала» → «Залы», «Добавить меню» → «Меню».
String scenarioRowLabel(String blockTitle) {
  final t = blockTitle.toLowerCase();
  const map = {
    'зал': 'Залы',
    'меню': 'Меню',
    'товар': 'Товары',
    'услуг': 'Услуги',
    'доставк': 'Доставка',
    'сотрудник': 'Сотрудники',
    'оплат': 'Оплата',
  };
  for (final e in map.entries) {
    if (t.contains(e.key)) return e.value;
  }
  final rest = blockTitle.replaceFirst(RegExp(r'^Добавить\s+', caseSensitive: false), '');
  return rest.isEmpty ? blockTitle : rest[0].toUpperCase() + rest.substring(1);
}

void _whereAmI(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: primaryBackground,
      title: const Text('Сценарии бизнеса', style: TextStyle(color: textPrimary)),
      content: const Text(
        'Сценарий связывает то, что вы добавили в форме: какие залы, меню, '
        'товары, услуги, доставка, сотрудники и оплата работают вместе. '
        'Отметьте нужное в каждой строке и сохраните. Сценариев может быть '
        'несколько, например «Завтраки» и «Банкет».',
        style: TextStyle(color: textSecondary, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Понятно', style: TextStyle(color: activeIconColor)),
        ),
      ],
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onBack,
              child: const Padding(
                padding: EdgeInsets.only(right: 6, top: 2),
                child: Icon(Icons.arrow_back_ios_new, color: textPrimary, size: 18),
              ),
            ),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onBack,
              child: const Text('Отмена', style: TextStyle(color: activeIconColor, fontSize: 15)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => _whereAmI(context),
          child: const Text('Где я нахожусь?', style: TextStyle(color: activeIconColor, fontSize: 14)),
        ),
        const SizedBox(height: 16),
        const Divider(color: _divider, height: 1),
        const SizedBox(height: 18),
      ],
    );
  }
}

Widget _primaryButton(String text, VoidCallback onTap) => SizedBox(
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

Widget _greenButton(String text, VoidCallback onTap) => SizedBox(
      height: 46,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _green),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(text, style: const TextStyle(color: _green, fontSize: 16)),
      ),
    );

// ------------------------------------------------------------
//  Список сценариев
// ------------------------------------------------------------

/// Возвращает новый список сценариев или null, если человек ушёл без
/// «Сохранить».
class ScenariosScreen extends StatefulWidget {
  const ScenariosScreen({super.key, required this.rows, required this.scenarios});

  final List<ScenarioRow> rows;
  final List<ScenarioDraft> scenarios;

  @override
  State<ScenariosScreen> createState() => _ScenariosScreenState();
}

class _ScenariosScreenState extends State<ScenariosScreen> {
  late final List<ScenarioDraft> _list = widget.scenarios.map((s) => s.copy()).toList();

  Future<void> _edit([int? index]) async {
    final result = await Navigator.push<ScenarioDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => ScenarioEditScreen(
          rows: widget.rows,
          initial: index == null ? null : _list[index],
          defaultName: 'Сценарий ${_list.length + 1}',
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() => index == null ? _list.add(result) : _list[index] = result);
  }

  Future<void> _delete(int index) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const _DeleteDialog());
    if (ok == true && mounted) setState(() => _list.removeAt(index));
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
                  _TopBar(title: 'Таблица распределения', onBack: () => Navigator.pop(context)),
                  if (_list.isNotEmpty)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (var i = 0; i < _list.length; i++)
                          _ScenarioCard(
                            scenario: _list[i],
                            rows: widget.rows,
                            onEdit: () => _edit(i),
                            onDelete: () => _delete(i),
                          ),
                      ],
                    ),
                  if (_list.isNotEmpty) const SizedBox(height: 18),
                  _greenButton('Создать сценарий', () => _edit()),
                  const SizedBox(height: 40),
                  _primaryButton('Сохранить', () => Navigator.pop(context, _list)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.scenario,
    required this.rows,
    required this.onEdit,
    required this.onDelete,
  });

  final ScenarioDraft scenario;
  final List<ScenarioRow> rows;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// «1 | 2 | 3»: номера отмеченного в порядке блока.
  String _numbers(ScenarioRow row) {
    final chosen = scenario.selected[row.blockId] ?? const [];
    final numbers = <int>[];
    for (var i = 0; i < row.items.length; i++) {
      if (chosen.contains(row.items[i])) numbers.add(i + 1);
    }
    return numbers.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 50 - 10) / 2;

    return Container(
      width: width,
      decoration: BoxDecoration(color: _tileBg, borderRadius: BorderRadius.circular(6)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
            child: Text(
              scenario.name,
              style: const TextStyle(color: textPrimary, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(color: _divider, height: 1),
          const SizedBox(height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: width * 0.48,
                    child: Text(row.label, style: const TextStyle(color: textSecondary, fontSize: 13)),
                  ),
                  Expanded(
                    child: Text(
                      _numbers(row).isEmpty ? '–' : _numbers(row),
                      style: const TextStyle(color: textPrimary, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          const Divider(color: _divider, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onEdit,
                  child: const Text('Изменить', style: TextStyle(color: activeIconColor, fontSize: 14)),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: onDelete,
                  child: const Text('Удалить', style: TextStyle(color: _red, fontSize: 14)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: primaryBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 14, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: const Icon(Icons.close, color: textPrimary),
              ),
            ),
            const Center(
              child: Text(
                'Удалить сценарий',
                style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 16),
            const Text.rich(
              TextSpan(children: [
                TextSpan(text: 'Внимание: ', style: TextStyle(color: Color(0xFFE8E22E))),
                TextSpan(text: 'сценарий будет удалён.', style: TextStyle(color: textPrimary)),
              ]),
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text('Подтвердите действие', style: TextStyle(color: textMuted, fontSize: 15)),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                      decorationColor: textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: activeIconColor),
                    minimumSize: const Size(127, 38),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Подтвердить', style: TextStyle(color: activeIconColor, fontSize: 16)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
//  Создание и правка
// ------------------------------------------------------------

class ScenarioEditScreen extends StatefulWidget {
  const ScenarioEditScreen({
    super.key,
    required this.rows,
    this.initial,
    required this.defaultName,
  });

  final List<ScenarioRow> rows;
  final ScenarioDraft? initial;
  final String defaultName;

  @override
  State<ScenarioEditScreen> createState() => _ScenarioEditScreenState();
}

class _ScenarioEditScreenState extends State<ScenarioEditScreen> {
  late final ScenarioDraft _draft =
      widget.initial?.copy() ?? ScenarioDraft(name: widget.defaultName);
  late final TextEditingController _name = TextEditingController(
    text: widget.initial == null ? '' : widget.initial!.name,
  );

  bool get _editing => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _toggle(ScenarioRow row, BlockItemDraft item) {
    setState(() {
      final list = _draft.selected.putIfAbsent(row.blockId, () => []);
      list.contains(item) ? list.remove(item) : list.add(item);
    });
  }

  /// Сотрудники, отмеченные на экранах блока «Добавить сотрудника»
  /// (25.09.2026).
  ///
  /// Справочник у человека общий, поэтому за стол ставим только тех, у кого на
  /// экране стоит галочка «работает здесь»: остальные к этому заведению
  /// отношения не имеют.
  List<StaffRef> get _staff {
    final people = <int, StaffRef>{};

    // По ключу позиции, а не по подписи строки: блок в админке могут
    // переименовать, а ключ «s<номер>» ставит сам сервер (25.09.2026).
    for (final row in widget.rows) {
      for (final screen in row.items) {
        for (final item in screen.menu.items) {
          if (!item.selected) continue;

          final person = StaffRef.tryFrom(item);
          if (person != null) people[person.id] = person;
        }
      }
    }

    return people.values.toList();
  }

  /// Стрелка у зала: «Настройка столов в зале» (22.09.2026). Столы
  /// записываются в зал, персонал столов в этот сценарий. Зал, у которого
  /// настроили столы, сразу отмечается в сценарии.
  Future<void> _openTables(ScenarioRow row, BlockItemDraft hall) async {
    final result = await Navigator.push<HallTablesResult>(
      context,
      MaterialPageRoute(
        builder: (_) => HallTablesScreen(
          hall: hall,
          staff: _staff,
          tableStaff: _draft.tables[hall] ?? const {},
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      if (result.staff.isEmpty) {
        _draft.tables.remove(hall);
      } else {
        _draft.tables[hall] = result.staff;
      }

      final list = _draft.selected.putIfAbsent(row.blockId, () => []);
      if (!list.contains(hall)) list.add(hall);
    });
  }

  void _show(ScenarioRow row, int index) {
    final item = row.items[index];

    if (row.label == 'Залы') {
      _openTables(row, item);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: secondaryBackground,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(25, 20, 25, 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${row.label}, № ${index + 1}',
                  style: const TextStyle(color: textSecondary, fontSize: 13)),
              const SizedBox(height: 6),
              Text(item.title,
                  style: const TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              for (final e in item.summary.skip(1))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('${e.key}: ${e.value}',
                      style: const TextStyle(color: textSecondary, fontSize: 14)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    if (_draft.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Отметьте хотя бы что-то: зал, меню, товар…'),
        backgroundColor: secondaryBackground,
      ));
      return;
    }

    final name = _name.text.trim();
    _draft.name = name.isEmpty ? (widget.initial?.name ?? widget.defaultName) : name;

    // Галочку могли снять уже после того, как человека поставили за стол
    // (25.09.2026): такие назначения снимаем, иначе сервер их всё равно
    // отбросит, а человек продолжал бы видеть их на плане.
    _draft.keepOnly(_staff);

    Navigator.pop(context, _draft);
  }

  @override
  Widget build(BuildContext context) {
    final anyItems = widget.rows.any((r) => r.items.isNotEmpty);

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
                  _TopBar(
                    title: _editing ? 'Редактировать сценарий бизнеса' : 'Создать сценарий бизнеса',
                    onBack: () => Navigator.pop(context),
                  ),
                  if (_editing) ...[
                    const Text('Название сценария', style: TextStyle(color: textPrimary, fontSize: 15)),
                    const SizedBox(height: 9),
                    Container(
                      height: 45,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: formBackground, borderRadius: BorderRadius.circular(6)),
                      child: TextField(
                        controller: _name,
                        style: const TextStyle(color: textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: widget.initial!.name.isEmpty ? 'Введите' : widget.initial!.name,
                          hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (!anyItems)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Сначала добавьте в форме залы, меню или другие блоки: '
                        'из них собирается сценарий.',
                        style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
                      ),
                    ),
                  for (final row in widget.rows) ...[
                    Text(row.label,
                        style: const TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        // По квадрату на добавленное; пустые места до трёх —
                        // серые, как на макете.
                        for (var i = 0; i < (row.items.length < 3 ? 3 : row.items.length); i++)
                          _Tile(
                            number: i + 1,
                            exists: i < row.items.length,
                            selected: i < row.items.length &&
                                (_draft.selected[row.blockId] ?? const []).contains(row.items[i]),
                            onTap: i < row.items.length ? () => _toggle(row, row.items[i]) : null,
                            onInfo: i < row.items.length ? () => _show(row, i) : null,
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                  const SizedBox(height: 10),
                  if (_draft.isEmpty)
                    _greenButton('Создать сценарий', _save)
                  else
                    _primaryButton('Сохранить', _save),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Квадрат с номером и стрелкой. Серый — пусто, белая рамка — есть,
/// зелёная — в сценарии.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.number,
    required this.exists,
    required this.selected,
    this.onTap,
    this.onInfo,
  });

  final int number;
  final bool exists;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    final border = !exists
        ? null
        : Border.all(color: selected ? _green : textPrimary, width: 1.2);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 52,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _tileBg,
              borderRadius: BorderRadius.circular(5),
              border: border,
            ),
            child: Text('$number', style: const TextStyle(color: textPrimary, fontSize: 15)),
          ),
        ),
        GestureDetector(
          onTap: onInfo,
          child: Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _tileBg, borderRadius: BorderRadius.circular(5)),
            child: Icon(
              Icons.chevron_right,
              color: exists ? textSecondary : textSecondary.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }
}
