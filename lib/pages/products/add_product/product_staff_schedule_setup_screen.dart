// ============================================================
// График работы: настройка периода и часов (макет 10.09.2026).
// ============================================================
//
// Открывается кнопкой «Настроить» с календаря. Здесь задаётся правило, по
// которому дни отмечаются сами, и рабочее время.
//
// Три способа задать период:
//
//  - по неделям: одни и те же дни недели каждую неделю;
//  - чередование: столько-то рабочих подряд, столько-то выходных;
//  - дни и часы: правила нет, дни человек отмечает в календаре руками.
//
// Экран ничего не сохраняет на сервер: он возвращает график календарю, а тот
// уходит на сервер уже вместе с карточкой сотрудника. Иначе «Отмена» на
// карточке оставляла бы у человека сохранённый график от несохранённого
// сотрудника.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/products/product_staff.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/components/custom_radio_button.dart';
import 'package:lidle/widgets/components/header.dart';

class ProductStaffScheduleSetupScreen extends StatefulWidget {
  const ProductStaffScheduleSetupScreen({super.key, required this.schedule});

  final StaffSchedule schedule;

  @override
  State<ProductStaffScheduleSetupScreen> createState() =>
      _ProductStaffScheduleSetupScreenState();
}

class _ProductStaffScheduleSetupScreenState
    extends State<ProductStaffScheduleSetupScreen> {
  late StaffSchedule _schedule = widget.schedule;

  static const List<String> _weekdayNames = [
    'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс',
  ];

  // Контроллеры намеренно не освобождаем: экран закрывается с анимацией, и
  // поля живут ещё несколько кадров. Освобождение здесь оставляет живой
  // TextField с мёртвым контроллером, а это зависание приложения.
  late final TextEditingController _work =
      TextEditingController(text: '${widget.schedule.rotationWork}');
  late final TextEditingController _rest =
      TextEditingController(text: '${widget.schedule.rotationRest}');

  void _setMode(StaffScheduleMode mode) {
    setState(() => _schedule = _schedule.copyWith(mode: mode));
  }

  void _toggleWeekday(int weekday) {
    final days = [..._schedule.weekdays];

    days.contains(weekday) ? days.remove(weekday) : days.add(weekday);

    setState(() => _schedule = _schedule.copyWith(weekdays: days..sort()));
  }

  void _readRotation() {
    final work = int.tryParse(_work.text.trim()) ?? _schedule.rotationWork;
    final rest = int.tryParse(_rest.text.trim()) ?? _schedule.rotationRest;

    _schedule = _schedule.copyWith(
      rotationWork: work.clamp(1, 31),
      rotationRest: rest.clamp(0, 31),
    );
  }

  Future<void> _openTime() async {
    final changed = await showDialog<StaffWorkTime>(
      context: context,
      builder: (context) => _WorkTimeDialog(time: _schedule.time),
    );

    if (changed != null && mounted) {
      setState(() => _schedule = _schedule.copyWith(time: changed));
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
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.chevron_left,
                        color: textPrimary, size: 26),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Настроить график',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Отмена',
                      style: TextStyle(color: activeIconColor, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  defaultPadding,
                  16,
                  defaultPadding,
                  16,
                ),
                children: [
                  const Text('Период',
                      style: TextStyle(color: textPrimary, fontSize: 15)),
                  const SizedBox(height: 10),

                  _modeRow(StaffScheduleMode.weeks, 'По неделям'),
                  _modeRow(
                      StaffScheduleMode.rotation, 'Чередование рабочих дней'),
                  _modeRow(StaffScheduleMode.days, 'Дни и часы'),

                  if (_schedule.mode == StaffScheduleMode.weeks) ...[
                    const SizedBox(height: 16),
                    const Text('Рабочие дни недели',
                        style: TextStyle(color: textPrimary, fontSize: 15)),
                    const SizedBox(height: 10),
                    _weekdays(),
                  ],

                  if (_schedule.mode == StaffScheduleMode.rotation) ...[
                    const SizedBox(height: 16),
                    _rotation(),
                  ],

                  if (_schedule.mode == StaffScheduleMode.days) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Дни отмечаются в календаре нажатием на число.',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Text('Рабочее время',
                      style: TextStyle(color: textPrimary, fontSize: 15)),
                  const SizedBox(height: 8),
                  _timeRow(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                defaultPadding,
                0,
                defaultPadding,
                16,
              ),
              child: GestureDetector(
                onTap: () {
                  _readRotation();

                  Navigator.pop(context, _schedule);
                },
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: activeIconColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Готово',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeRow(StaffScheduleMode mode, String title) {
    return GestureDetector(
      onTap: () => _setMode(mode),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CustomRadioButton<StaffScheduleMode>(
              value: mode,
              groupValue: _schedule.mode,
              onChanged: (value) => _setMode(value ?? mode),
              selectedBorderColor: const Color(0xFF888888),
              unselectedBorderColor: const Color(0xFF888888),
              selectedFillColor: activeIconColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: textPrimary, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekdays() {
    return Row(
      children: [
        for (var index = 0; index < _weekdayNames.length; index++)
          Expanded(
            child: GestureDetector(
              onTap: () => _toggleWeekday(index + 1),
              child: Container(
                height: 40,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _schedule.weekdays.contains(index + 1)
                      ? activeIconColor
                      : formBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _weekdayNames[index],
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _rotation() {
    return Row(
      children: [
        Expanded(child: _number('Рабочих дней', _work)),
        const SizedBox(width: 12),
        Expanded(child: _number('Выходных', _rest)),
      ],
    );
  }

  Widget _number(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textSecondary, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: formBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(_readRotation),
            style: const TextStyle(color: textPrimary, fontSize: 15),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '2',
              hintStyle: TextStyle(color: textMuted, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _timeRow() {
    final time = _schedule.time;

    final label = time.allDay
        ? 'Весь день'
        : '${time.start} – ${time.end}'
            '${time.hasBreak ? ', перерыв ${time.breakStart} – ${time.breakEnd}' : ''}';

    return GestureDetector(
      onTap: _openTime,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: textPrimary, fontSize: 15),
              ),
            ),
            const Icon(Icons.chevron_right, color: textMuted, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Диалог «Рабочее время».
///
/// «Весь день» прячет часы: круглосуточная смена и смена «с 9 до 18» это
/// разные вещи, и оставлять на экране поля, которые ни на что не влияют,
/// значит собирать вопросы.
class _WorkTimeDialog extends StatefulWidget {
  const _WorkTimeDialog({required this.time});

  final StaffWorkTime time;

  @override
  State<_WorkTimeDialog> createState() => _WorkTimeDialogState();
}

class _WorkTimeDialogState extends State<_WorkTimeDialog> {
  late StaffWorkTime _time = widget.time;
  late bool _hasBreak = widget.time.hasBreak;

  /// Включить или убрать перерыв.
  ///
  /// Час на обед подставляем сразу: пустые поля «с» и «до» человеку всё равно
  /// придётся заполнить, а так он их только поправит.
  void _switchBreak() {
    setState(() {
      _hasBreak = !_hasBreak;

      _time = _hasBreak
          ? _time.copyWith(
              breakStart: _time.breakStart ?? '13:00',
              breakEnd: _time.breakEnd ?? '14:00',
            )
          : _time.copyWith(dropBreak: true);
    });
  }

  Future<void> _pick(String current, ValueChanged<String> apply) async {
    final parts = current.split(':');

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 9,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      ),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: activeIconColor,
            surface: secondaryBackground,
          ),
        ),
        child: child ?? const SizedBox(),
      ),
    );

    if (picked == null || !mounted) return;

    final text = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';

    setState(() => apply(text));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: secondaryBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Рабочее время',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: textPrimary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _choice(
              'Рабочий день',
              selected: !_time.allDay,
              onTap: () => setState(
                () => _time = _time.copyWith(allDay: false),
              ),
            ),
            _choice(
              'Весь день',
              selected: _time.allDay,
              onTap: () => setState(
                () => _time = _time.copyWith(allDay: true),
              ),
            ),

            if (!_time.allDay) ...[
              const SizedBox(height: 12),
              _pair(
                fromLabel: 'С',
                from: _time.start,
                toLabel: 'До',
                to: _time.end,
                onFrom: (value) => _time = _time.copyWith(start: value),
                onTo: (value) => _time = _time.copyWith(end: value),
              ),
            ],

            const SizedBox(height: 12),
            GestureDetector(
              onTap: _switchBreak,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  CustomCheckbox(
                    value: _hasBreak,
                    onChanged: (_) => _switchBreak(),
                  ),
                  const SizedBox(width: 12),
                  const Text('Перерыв',
                      style: TextStyle(color: textPrimary, fontSize: 15)),
                ],
              ),
            ),

            if (_hasBreak) ...[
              const SizedBox(height: 12),
              _pair(
                fromLabel: 'С',
                from: _time.breakStart ?? '13:00',
                toLabel: 'До',
                to: _time.breakEnd ?? '14:00',
                onFrom: (value) => _time = _time.copyWith(breakStart: value),
                onTo: (value) => _time = _time.copyWith(breakEnd: value),
              ),
            ],

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(context, _time),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: activeIconColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Готово',
                      style: TextStyle(color: activeIconColor, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _choice(
    String title, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CustomRadioButton<bool>(
              value: true,
              groupValue: selected ? true : false,
              onChanged: (_) => onTap(),
              selectedBorderColor: const Color(0xFF888888),
              unselectedBorderColor: const Color(0xFF888888),
              selectedFillColor: activeIconColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: textPrimary, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pair({
    required String fromLabel,
    required String from,
    required String toLabel,
    required String to,
    required ValueChanged<String> onFrom,
    required ValueChanged<String> onTo,
  }) {
    return Row(
      children: [
        Expanded(child: _field(fromLabel, from, () => _pick(from, onFrom))),
        const SizedBox(width: 12),
        Expanded(child: _field(toLabel, to, () => _pick(to, onTo))),
      ],
    );
  }

  Widget _field(String label, String value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textSecondary, fontSize: 13)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 44,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: formBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: const TextStyle(color: textPrimary, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}
