// ============================================================
// "Диалог выбора одного значения" — компания (макет 11.09.2026).
// ============================================================
//
// Один на три поля: валюта расчёта, язык уведомлений клиентов и язык
// уведомлений сотрудников. Отличаются они только заголовком и списком, а три
// почти одинаковых диалога разъехались бы при первой же правке.
//
// Список приходит с сервера вместе с названиями: приложение не держит второй
// копии, иначе переименование пункта потребовало бы новой версии.
//
// Кнопка называется «Подтвердить», как на макете. Крестик и нажатие мимо
// закрывают, ничего не меняя: человек мог открыть диалог посмотреть.

import 'package:flutter/material.dart';
import 'package:lidle/widgets/components/custom_radio_button.dart';

/// Пункт выбора: код уходит на сервер, название видит человек.
class CompanyChoiceOption {
  const CompanyChoiceOption({required this.code, required this.title, this.note});

  final String code;
  final String title;

  /// Приписка серым, например «(RUB)».
  final String? note;
}

/// Показать диалог. Возвращает код выбранного пункта или null.
Future<String?> showCompanyChoiceDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<CompanyChoiceOption> options,
  String? selected,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _CompanyChoiceDialog(
      title: title,
      subtitle: subtitle,
      options: options,
      selected: selected,
    ),
  );
}

class _CompanyChoiceDialog extends StatefulWidget {
  const _CompanyChoiceDialog({
    required this.title,
    required this.options,
    this.subtitle,
    this.selected,
  });

  final String title;
  final String? subtitle;
  final List<CompanyChoiceOption> options;
  final String? selected;

  @override
  State<_CompanyChoiceDialog> createState() => _CompanyChoiceDialogState();
}

class _CompanyChoiceDialogState extends State<_CompanyChoiceDialog> {
  static const accentColor = Color(0xFF00B7FF);

  /// Что отмечено. Пусто — берём первый пункт: диалог с одним выбором и без
  /// отметки выглядит сломанным, а «Подтвердить» тогда ничего не значит.
  late String? _chosen = widget.selected ??
      (widget.options.isEmpty ? null : widget.options.first.code);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E2A38),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ],
            ),

            const SizedBox(height: 18),

            for (final option in widget.options)
              GestureDetector(
                onTap: () => setState(() => _chosen = option.code),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: option.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                            children: option.note == null
                                ? null
                                : [
                                    TextSpan(
                                      text: ' ${option.note}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                          ),
                        ),
                      ),
                      CustomRadioButton<String>(
                        value: option.code,
                        groupValue: _chosen,
                        onChanged: (value) =>
                            setState(() => _chosen = value ?? option.code),
                        selectedBorderColor: accentColor,
                        unselectedBorderColor: const Color(0xFF888888),
                        selectedFillColor: accentColor,
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: accentColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(context, _chosen),
                child: const Text(
                  'Подтвердить',
                  style: TextStyle(color: accentColor, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
