// ============================================================
// График работы: диалог «Рабочее время» (макет 10.09.2026).
// ============================================================
//
// Отдельным файлом: он понадобится и в «Днях и часах», и в чередовании, а
// класть один и тот же диалог в каждый экран значит однажды получить три
// разных диалога с одним названием.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/products/product_staff.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/components/custom_radio_button.dart';

/// Показать диалог «Рабочее время». Возвращает `null`, если передумали.
Future<StaffWorkTime?> showWorkTimeDialog(
  BuildContext context,
  StaffWorkTime time,
) {
  return showDialog<StaffWorkTime>(
    context: context,
    builder: (context) => _WorkTimeDialog(time: time),
  );
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
