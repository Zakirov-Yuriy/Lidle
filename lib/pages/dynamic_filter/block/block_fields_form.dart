// ============================================================
//  Поля экрана блока «Добавить …» (22.09.2026)
// ============================================================
//
// «Название зала», «Цена бронирования столика», «Вид зала», «Этаж зала» на
// экране «Добавить общий план ресторана» это атрибуты из админки,
// привязанные к блоку. Рисуем их теми же виджетами, что форму подачи
// объявления, по тому же правилу `resolveFilterField`: человек видит
// привычные поля и окна выбора.
//
// Значения собираются в том виде, в каком их ждёт сервер
// (`AttributesWithCategoryRule`):
//   выбор        → value_selected: [номера вариантов]
//   текст        → values[id] = {value}
//   число от/до  → values[id] = {value, max_value}
//   время (T)    → values[id] = {value: «18:00», value_to: «04:00»}
//   даты (J, K)  → values[id] = {value: «2026-09-22 00:00», value_to: …}

import 'package:flutter/material.dart';
import 'package:lidle/models/filter_models.dart';
import 'package:lidle/pages/dynamic_filter/dynamic_filter_field_resolver.dart';
import 'package:lidle/pages/dynamic_filter/widgets/boolean_field.dart';
import 'package:lidle/pages/dynamic_filter/widgets/checkbox_field.dart';
import 'package:lidle/pages/dynamic_filter/widgets/dynamic_text_input_field.dart';
import 'package:lidle/pages/dynamic_filter/widgets/multiple_select_dropdown_field.dart';
import 'package:lidle/pages/dynamic_filter/widgets/multiple_select_popup_field.dart';
import 'package:lidle/pages/dynamic_filter/widgets/numeric_input_field.dart';
import 'package:lidle/pages/dynamic_filter/widgets/period_fields.dart';
import 'package:lidle/pages/dynamic_filter/widgets/price_input_field.dart';
import 'package:lidle/pages/dynamic_filter/widgets/range_field.dart';
import 'package:lidle/pages/dynamic_filter/widgets/single_select_dropdown_field.dart';

class BlockFieldsController {
  BlockFieldsController(this.fields);

  final List<Attribute> fields;

  final Map<int, Set<String>> _selected = {};
  final Map<int, bool> _flags = {};
  final Map<int, TextEditingController> _texts = {};
  final Map<int, TextEditingController> _min = {};
  final Map<int, TextEditingController> _max = {};
  final Map<int, String?> _timeFrom = {};
  final Map<int, String?> _timeTo = {};
  final Map<int, DateTime?> _dateFrom = {};
  final Map<int, DateTime?> _dateTo = {};

  TextEditingController text(int id) => _texts.putIfAbsent(id, TextEditingController.new);
  TextEditingController min(int id) => _min.putIfAbsent(id, TextEditingController.new);
  TextEditingController max(int id) => _max.putIfAbsent(id, TextEditingController.new);

  Set<String> selected(int id) => _selected[id] ?? <String>{};
  bool flag(int id) => _flags[id] ?? false;

  FilterFieldKind _kind(Attribute a) => resolveFilterField(a).kind;

  bool _isDate(Attribute a) {
    final k = _kind(a);
    return k == FilterFieldKind.rentTime || k == FilterFieldKind.rentTimeCompact;
  }

  /// Подставить сохранённое (правка зала).
  void prefill(Map<String, dynamic> saved) {
    final ids = (saved['value_selected'] as List? ?? const [])
        .map((e) => (e as num).toInt())
        .toSet();
    final values = saved['values'] is Map
        ? Map<String, dynamic>.from(saved['values'] as Map)
        : <String, dynamic>{};

    for (final field in fields) {
      final chosen = field.values.where((v) => ids.contains(v.id)).toList();

      if (chosen.isNotEmpty) {
        _selected[field.id] = chosen.map((v) => v.value).toSet();
        if (_kind(field) == FilterFieldKind.checkbox ||
            _kind(field) == FilterFieldKind.boolean) {
          _flags[field.id] = true;
        }
        continue;
      }

      final raw = values['${field.id}'];
      if (raw is! Map) continue;

      final from = raw['value']?.toString();
      final to = (raw['value_to'] ?? raw['max_value'])?.toString();

      switch (_kind(field)) {
        case FilterFieldKind.range:
          if (from != null) min(field.id).text = from;
          if (to != null) max(field.id).text = to;
        case FilterFieldKind.timeRange:
          _timeFrom[field.id] = from;
          _timeTo[field.id] = to;
        case FilterFieldKind.rentTime:
        case FilterFieldKind.rentTimeCompact:
          _dateFrom[field.id] = parseDate(from);
          _dateTo[field.id] = parseDate(to);
        default:
          if (from != null) text(field.id).text = from;
      }
    }
  }

  /// Незаполненные обязательные поля.
  List<String> missingRequired() {
    final missing = <String>[];

    for (final field in fields) {
      if (!field.isRequired) continue;

      final filled = selected(field.id).isNotEmpty ||
          flag(field.id) ||
          (_texts[field.id]?.text.trim().isNotEmpty ?? false) ||
          (_min[field.id]?.text.trim().isNotEmpty ?? false) ||
          _timeFrom[field.id] != null ||
          _dateFrom[field.id] != null;

      if (!filled) missing.add(field.title);
    }

    return missing;
  }

  /// Ошибки, которые сервер всё равно вернёт: «До» без «От».
  String? rangeProblem() {
    for (final field in fields) {
      if (_kind(field) != FilterFieldKind.range) continue;
      final from = _min[field.id]?.text.trim() ?? '';
      final to = _max[field.id]?.text.trim() ?? '';
      if (from.isEmpty && to.isNotEmpty) return 'Заполните «От» в поле «${field.title}»';
    }
    return null;
  }

  Map<String, dynamic> payload() {
    final ids = <int>[];
    final values = <String, dynamic>{};

    for (final field in fields) {
      final kind = _kind(field);
      final chosen = selected(field.id);

      if (chosen.isNotEmpty && field.values.isNotEmpty) {
        final many = resolveFilterField(field).attribute.isMultiple;
        for (final title in many ? chosen : {chosen.first}) {
          final match = field.values.where((v) => v.value == title);
          if (match.isNotEmpty) ids.add(match.first.id);
        }
        continue;
      }

      if (flag(field.id) && field.values.isNotEmpty) {
        ids.add(field.values.first.id);
        continue;
      }

      if (kind == FilterFieldKind.range) {
        final from = _min[field.id]?.text.trim() ?? '';
        final to = _max[field.id]?.text.trim() ?? '';
        if (from.isNotEmpty) {
          values['${field.id}'] = {
            'value': int.tryParse(from) ?? from,
            if (to.isNotEmpty) 'max_value': int.tryParse(to) ?? to,
          };
        }
        continue;
      }

      if (kind == FilterFieldKind.timeRange) {
        final from = _timeFrom[field.id];
        if (from != null) {
          values['${field.id}'] = {
            'value': from,
            if (_timeTo[field.id] != null) 'value_to': _timeTo[field.id],
          };
        }
        continue;
      }

      if (_isDate(field)) {
        final from = _dateFrom[field.id];
        if (from != null) {
          values['${field.id}'] = {
            'value': serverDate(from),
            if (_dateTo[field.id] != null) 'value_to': serverDate(_dateTo[field.id]!, end: true),
          };
        }
        continue;
      }

      final t = _texts[field.id]?.text.trim() ?? '';
      if (t.isNotEmpty) values['${field.id}'] = {'value': t};
    }

    return {'value_selected': ids, 'values': values};
  }

  /// Строки «Поле: значение» для списка залов в форме объявления.
  List<MapEntry<String, String>> summary() {
    final out = <MapEntry<String, String>>[];

    for (final field in fields) {
      String? v;
      final chosen = selected(field.id);

      if (chosen.isNotEmpty) {
        v = chosen.join(', ');
      } else if (flag(field.id)) {
        v = 'да';
      } else {
        switch (_kind(field)) {
          case FilterFieldKind.range:
            final a = _min[field.id]?.text.trim() ?? '';
            final b = _max[field.id]?.text.trim() ?? '';
            final unit = (field.vmText ?? '').trim().length <= 2 ? ' ${field.vmText ?? ''}'.trimRight() : '';
            if (a.isNotEmpty) v = b.isNotEmpty ? 'от $a до $b$unit' : '$a$unit';
          case FilterFieldKind.timeRange:
            final a = _timeFrom[field.id];
            if (a != null) v = 'с $a${_timeTo[field.id] != null ? ' до ${_timeTo[field.id]}' : ''}';
          case FilterFieldKind.rentTime:
          case FilterFieldKind.rentTimeCompact:
            final a = _dateFrom[field.id];
            if (a != null) {
              v = 'с ${showDate(a)}${_dateTo[field.id] != null ? ' до ${showDate(_dateTo[field.id]!)}' : ''}';
            }
          default:
            final t = _texts[field.id]?.text.trim() ?? '';
            if (t.isNotEmpty) v = t;
        }
      }

      if (v != null && v.isNotEmpty) out.add(MapEntry(field.title, v));
    }

    return out;
  }

  void dispose() {
    for (final c in [..._texts.values, ..._min.values, ..._max.values]) {
      c.dispose();
    }
  }
}

class BlockFieldsForm extends StatefulWidget {
  const BlockFieldsForm({super.key, required this.controller});

  final BlockFieldsController controller;

  @override
  State<BlockFieldsForm> createState() => _BlockFieldsFormState();
}

class _BlockFieldsFormState extends State<BlockFieldsForm> {
  BlockFieldsController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final field in c.fields)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _field(field),
          ),
      ],
    );
  }

  Widget _field(Attribute attr) {
    final plan = resolveFilterField(attr);
    final a = plan.attribute;

    switch (plan.kind) {
      case FilterFieldKind.checkbox:
      case FilterFieldKind.hiddenCheckbox:
        return CheckboxField(
          attribute: a,
          value: c.flag(a.id),
          onChanged: (v) => setState(() => c._flags[a.id] = v),
        );
      case FilterFieldKind.boolean:
        return BooleanField(
          attribute: a,
          value: c.flag(a.id),
          onChanged: (v) => setState(() => c._flags[a.id] = v),
        );
      case FilterFieldKind.price:
        return PriceInputField(attribute: a, controller: c.text(a.id), onChanged: (_) {});
      case FilterFieldKind.numericInput:
        return NumericInputField(attribute: a, controller: c.text(a.id), onChanged: (_) {});
      case FilterFieldKind.textInput:
        return DynamicTextInputField(attribute: a, controller: c.text(a.id), onChanged: (_) {});
      case FilterFieldKind.range:
        return RangeField(
          attribute: a,
          controllerMin: c.min(a.id),
          controllerMax: c.max(a.id),
          onMinChanged: (_) {},
          onMaxChanged: (_) {},
        );
      case FilterFieldKind.singleSelect:
        return SingleSelectDropdownField(
          attribute: a,
          selectedValue: c.selected(a.id).isEmpty ? '' : c.selected(a.id).first,
          onChanged: (v) => setState(() => c._selected[a.id] = v.isEmpty ? <String>{} : {v}),
        );
      case FilterFieldKind.multipleSelect:
        return MultipleSelectDropdownField(
          attribute: a,
          selectedValues: c.selected(a.id),
          onChanged: (v) => setState(() => c._selected[a.id] = v),
        );
      case FilterFieldKind.multipleSelectPopup:
      case FilterFieldKind.buttonGroup:
        return MultipleSelectPopupField(
          attribute: plan.kind == FilterFieldKind.buttonGroup
              ? a.copyWith(isMultiple: false)
              : a,
          showSelectAll: true,
          selectedValues: c.selected(a.id),
          onChanged: (v) => setState(() => c._selected[a.id] = v),
        );
      case FilterFieldKind.timeRange:
        return TimeRangeField(
          attribute: a,
          from: c._timeFrom[a.id],
          to: c._timeTo[a.id],
          onChanged: (f, t) => setState(() {
            c._timeFrom[a.id] = f;
            c._timeTo[a.id] = t;
          }),
        );
      case FilterFieldKind.rentTime:
      case FilterFieldKind.rentTimeCompact:
        return DateRangeBoxesField(
          attribute: a,
          from: c._dateFrom[a.id],
          to: c._dateTo[a.id],
          onChanged: (f, t) => setState(() {
            c._dateFrom[a.id] = f;
            c._dateTo[a.id] = t;
          }),
        );
      // Бронь и блоки-оформление на экране блока не рисуются.
      case FilterFieldKind.booking:
      case FilterFieldKind.addList:
      case FilterFieldKind.linkBlock:
        return const SizedBox.shrink();
    }
  }
}
