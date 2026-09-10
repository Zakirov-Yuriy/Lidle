// ============================================================
// Характеристики товара: динамическая часть формы позиции.
// ============================================================
//
// «Тип одежды», «С принтом», «Выберите размер», «Цвет» на макете от
// 09.09.2026 — это не отдельные поля, а характеристики раздела. Их набор
// заводится в супер-админке и приезжает ручкой
// `GET /v1/me/products/attributes?category_id=`.
//
// Виджеты полей и правило «какой стиль каким полем рисовать» взяты у формы
// подачи объявления БЕЗ ИЗМЕНЕНИЙ (`dynamic_filter/widgets`,
// `resolveFilterField`). Это осознанно: человек уже привык к этим полям и
// диалогам, а вторая реализация тех же стилей разъехалась бы с первой на
// первой же правке.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/filter_models.dart';
import 'package:lidle/models/products/product_publication.dart';
import 'package:lidle/pages/dynamic_filter/dynamic_filter_field_resolver.dart';
import 'package:lidle/pages/dynamic_filter/widgets/boolean_field.dart';
import 'package:lidle/pages/dynamic_filter/widgets/button_group_field.dart';
import 'package:lidle/pages/dynamic_filter/widgets/checkbox_field.dart';
import 'package:lidle/pages/dynamic_filter/widgets/dynamic_text_input_field.dart';
import 'package:lidle/pages/dynamic_filter/widgets/multiple_select_dropdown_field.dart';
import 'package:lidle/pages/dynamic_filter/widgets/multiple_select_popup_field.dart';
import 'package:lidle/pages/dynamic_filter/widgets/numeric_input_field.dart';
import 'package:lidle/pages/dynamic_filter/widgets/price_input_field.dart';
import 'package:lidle/pages/dynamic_filter/widgets/range_field.dart';
import 'package:lidle/pages/dynamic_filter/widgets/single_select_dropdown_field.dart';

/// Состояние заполненных характеристик и сборка тела запроса.
///
/// Живёт отдельно от виджета, чтобы экран позиции мог спросить payload в
/// момент сохранения, не разбирая дерево виджетов.
class ProductAttributesController {
  final Map<int, Set<String>> _selected = {};
  final Map<int, bool> _flags = {};
  final Map<int, TextEditingController> _texts = {};
  final Map<int, TextEditingController> _min = {};
  final Map<int, TextEditingController> _max = {};

  List<Attribute> _fields = const [];

  set fields(List<Attribute> value) => _fields = value;

  List<Attribute> get fields => _fields;

  TextEditingController text(int id) =>
      _texts.putIfAbsent(id, () => TextEditingController());

  TextEditingController min(int id) =>
      _min.putIfAbsent(id, () => TextEditingController());

  TextEditingController max(int id) =>
      _max.putIfAbsent(id, () => TextEditingController());

  Set<String> selected(int id) => _selected[id] ?? <String>{};

  bool flag(int id) => _flags[id] ?? false;

  void setSelected(int id, Set<String> values) => _selected[id] = values;

  void setFlag(int id, bool value) => _flags[id] = value;

  /// Подставить уже сохранённое: правка открывается заполненной формой.
  ///
  /// Выбранные варианты приходят номерами значений, а поля хранят их
  /// названиями — поэтому номера переводим по справочнику раздела. Значит,
  /// подставлять надо ПОСЛЕ того, как поля загружены: иначе переводить не по
  /// чему.
  ///
  /// Характеристику, которой в разделе больше нет (администратор удалил),
  /// молча пропускаем: показать её всё равно нечем.
  void prefill(List<ProductPositionAttribute> saved) {
    for (final item in saved) {
      final match = _fields.where((field) => field.id == item.id);

      if (match.isEmpty) continue;

      final field = match.first;

      if (item.valueIds.isNotEmpty) {
        final titles = field.values
            .where((value) => item.valueIds.contains(value.id))
            .map((value) => value.value)
            .toSet();

        if (titles.isNotEmpty) {
          _selected[item.id] = titles;

          // Характеристика с единственным значением рисуется переключателем
          // («С принтом»), и её состояние живёт отдельно от выбора.
          if (field.values.length == 1) _flags[item.id] = true;

          continue;
        }
      }

      if (item.value.isNotEmpty) text(item.id).text = item.value;
    }
  }

  /// Названия незаполненных обязательных полей.
  ///
  /// Проверяем и на клиенте тоже, хотя сервер это делает сам: иначе человек
  /// заполняет длинную форму, жмёт «Сохранить» и только тогда узнаёт, что
  /// пропустил поле в середине.
  List<String> missingRequired() {
    final missing = <String>[];

    for (final attr in _fields) {
      if (!attr.isRequired) continue;

      final hasChoice = selected(attr.id).isNotEmpty;
      final hasText = (_texts[attr.id]?.text ?? '').trim().isNotEmpty;
      final hasRange = (_min[attr.id]?.text ?? '').trim().isNotEmpty ||
          (_max[attr.id]?.text ?? '').trim().isNotEmpty;
      final hasFlag = _flags[attr.id] == true;

      if (!hasChoice && !hasText && !hasRange && !hasFlag) {
        missing.add(attr.title);
      }
    }

    return missing;
  }

  /// Тело запроса: `attributes` для `POST /v1/me/products`.
  ///
  /// Выбранные варианты уезжают НОМЕРАМИ значений (`value_selected`), а
  /// свободный текст и диапазоны — в `values` по номеру атрибута. Ровно так
  /// же собирает форму подачи объявления.
  Map<String, dynamic> payload() {
    final selectedIds = <int>[];
    final values = <String, dynamic>{};

    for (final attr in _fields) {
      final chosen = selected(attr.id);

      if (chosen.isNotEmpty) {
        // Атрибут с одним значением: даже если человек успел отметить
        // несколько, отправляем первое. Сервер второе всё равно отклонит.
        final take = attr.isMultiple ? chosen : {chosen.first};

        for (final title in take) {
          final match = attr.values.where((v) => v.value == title);

          if (match.isNotEmpty) {
            selectedIds.add(match.first.id);
          }
        }

        continue;
      }

      if (_flags[attr.id] == true && attr.values.isNotEmpty) {
        selectedIds.add(attr.values.first.id);

        continue;
      }

      final minText = (_min[attr.id]?.text ?? '').trim();
      final maxText = (_max[attr.id]?.text ?? '').trim();

      if (minText.isNotEmpty || maxText.isNotEmpty) {
        values['${attr.id}'] = {
          if (minText.isNotEmpty) 'value': minText,
          if (maxText.isNotEmpty) 'value_to': maxText,
        };

        continue;
      }

      final text = (_texts[attr.id]?.text ?? '').trim();

      if (text.isNotEmpty) {
        values['${attr.id}'] = {'value': text};
      }
    }

    return {
      'values': values,
      'value_selected': selectedIds,
    };
  }

  void dispose() {
    for (final controller in [..._texts.values, ..._min.values, ..._max.values]) {
      controller.dispose();
    }
  }
}

/// Список полей характеристик раздела.
class ProductAttributesForm extends StatefulWidget {
  const ProductAttributesForm({
    super.key,
    required this.controller,
    required this.fields,
  });

  final ProductAttributesController controller;
  final List<Attribute> fields;

  @override
  State<ProductAttributesForm> createState() => _ProductAttributesFormState();
}

class _ProductAttributesFormState extends State<ProductAttributesForm> {
  @override
  void initState() {
    super.initState();
    widget.controller.fields = widget.fields;
  }

  @override
  void didUpdateWidget(covariant ProductAttributesForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller.fields = widget.fields;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fields.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.fields.map(_buildField).toList(),
    );
  }

  Widget _buildField(Attribute attr) {
    // Правила общие с подачей объявления. Одно отличие — несколько значений
    // у позиции (несколько цветов) — решает сервер: он отдаёт такому полю
    // стиль F, см. ProductFieldResource на бэкенде.
    final plan = resolveFilterField(attr);
    final field = plan.attribute;
    final controller = widget.controller;

    switch (plan.kind) {
      // Метки категории: бронирование и календари аренды. У товара их не
      // бывает, а если атрибут всё же заведён, показывать пустое поле хуже,
      // чем не показывать ничего.
      case FilterFieldKind.booking:
      case FilterFieldKind.rentTime:
      case FilterFieldKind.rentTimeCompact:
        return const SizedBox.shrink();

      case FilterFieldKind.checkbox:
      case FilterFieldKind.hiddenCheckbox:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: CheckboxField(
            attribute: field,
            value: controller.flag(field.id),
            onChanged: (value) =>
                setState(() => controller.setFlag(field.id, value)),
          ),
        );

      case FilterFieldKind.boolean:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: BooleanField(
            attribute: field,
            value: controller.flag(field.id),
            onChanged: (value) =>
                setState(() => controller.setFlag(field.id, value)),
          ),
        );

      case FilterFieldKind.price:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: PriceInputField(
            attribute: field,
            controller: controller.text(field.id),
            onChanged: (_) {},
          ),
        );

      case FilterFieldKind.numericInput:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: NumericInputField(
            attribute: field,
            controller: controller.text(field.id),
            onChanged: (_) {},
          ),
        );

      case FilterFieldKind.textInput:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DynamicTextInputField(
            attribute: field,
            controller: controller.text(field.id),
            onChanged: (_) {},
          ),
        );

      case FilterFieldKind.range:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: RangeField(
            attribute: field,
            controllerMin: controller.min(field.id),
            controllerMax: controller.max(field.id),
            onMinChanged: (_) {},
            onMaxChanged: (_) {},
          ),
        );

      case FilterFieldKind.singleSelect:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SingleSelectDropdownField(
            attribute: field,
            selectedValue: controller.selected(field.id).isEmpty
                ? ''
                : controller.selected(field.id).first,
            onChanged: (value) => setState(
              () => controller.setSelected(
                field.id,
                value.isEmpty ? <String>{} : {value},
              ),
            ),
          ),
        );

      case FilterFieldKind.multipleSelect:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: MultipleSelectDropdownField(
            attribute: field,
            selectedValues: controller.selected(field.id),
            onChanged: (values) =>
                setState(() => controller.setSelected(field.id, values)),
          ),
        );

      case FilterFieldKind.multipleSelectPopup:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: MultipleSelectPopupField(
            attribute: field,
            selectedValues: controller.selected(field.id),
            onChanged: (values) =>
                setState(() => controller.setSelected(field.id, values)),
          ),
        );

      case FilterFieldKind.buttonGroup:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ButtonGroupField(
            attribute: field,
            selectedValue: controller.selected(field.id).isEmpty
                ? ''
                : controller.selected(field.id).first,
            onChanged: (value) => setState(
              () => controller.setSelected(
                field.id,
                value.isEmpty ? <String>{} : {value},
              ),
            ),
          ),
        );
    }
  }
}

/// Подпись-подсказка под формой, когда характеристик у раздела нет.
class ProductAttributesEmptyHint extends StatelessWidget {
  const ProductAttributesEmptyHint({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Text(
        'У этого раздела пока нет характеристик. Их заводит администратор.',
        style: TextStyle(color: textSecondary, fontSize: 13),
      ),
    );
  }
}
