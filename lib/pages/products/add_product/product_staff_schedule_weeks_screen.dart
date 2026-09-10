// ============================================================
// График работы: «По неделям» (макет 10.09.2026).
// ============================================================
//
// Открывается карточкой «По неделям» на экране настройки периода. Выбор один
// из четырёх, поэтому кружки, а не галочки.
//
// «Чётные» и «нечётные» это числа месяца, как о них и говорят вслух:
// «работаю по чётным». Блок на макете подписан «Рабочие недели», но выбор
// именно про числа.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/products/product_staff.dart';
import 'package:lidle/widgets/components/custom_radio_button.dart';
import 'package:lidle/widgets/components/header.dart';

class ProductStaffScheduleWeeksScreen extends StatefulWidget {
  const ProductStaffScheduleWeeksScreen({super.key, this.preset});

  /// Что выбрано сейчас. Пусто — ещё не настраивали.
  final String? preset;

  @override
  State<ProductStaffScheduleWeeksScreen> createState() =>
      _ProductStaffScheduleWeeksScreenState();
}

class _ProductStaffScheduleWeeksScreenState
    extends State<ProductStaffScheduleWeeksScreen> {
  /// Первым стоит «Все дни»: это самый частый ответ, и человеку, которому
  /// нечего настраивать, хватит одного нажатия.
  static const List<String> _presets = ['all', 'workdays', 'even', 'odd'];

  late String _chosen = widget.preset ?? 'all';

  void _explain() {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: secondaryBackground,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'По неделям',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Все дни — сотрудник работает каждый день.\n\n'
                'Будни — с понедельника по пятницу, суббота и воскресенье '
                'выходные.\n\n'
                'Чётные и нечётные — по числам месяца: 2, 4, 6 и так далее '
                'или 1, 3, 5.',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Понятно',
                    style: TextStyle(color: activeIconColor, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
                      'По неделям',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // «Отмена» уходит без выбора: карточка остаётся такой, какой
                  // была.
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
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: _explain,
                  child: const Text(
                    'Как это работает?',
                    style: TextStyle(color: activeIconColor, fontSize: 14),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  defaultPadding,
                  14,
                  defaultPadding,
                  16,
                ),
                children: [
                  for (final preset in _presets) _row(preset),
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
                onTap: () => Navigator.pop(context, _chosen),
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: activeIconColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Сохранить',
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

  Widget _row(String preset) {
    return GestureDetector(
      onTap: () => setState(() => _chosen = preset),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                StaffSchedule.weeksPresetTitle(preset),
                style: const TextStyle(color: textPrimary, fontSize: 16),
              ),
            ),
            CustomRadioButton<String>(
              value: preset,
              groupValue: _chosen,
              onChanged: (value) => setState(() => _chosen = value ?? preset),
              selectedBorderColor: const Color(0xFF888888),
              unselectedBorderColor: const Color(0xFF888888),
              selectedFillColor: activeIconColor,
            ),
          ],
        ),
      ),
    );
  }
}
