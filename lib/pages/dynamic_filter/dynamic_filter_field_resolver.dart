import 'package:lidle/models/filter_models.dart';

/// Тип UI-поля, который нужно построить для динамического атрибута
/// фильтра. Резолвер возвращает одно из этих значений на основании
/// флагов и стилей атрибута; вызывающая сторона диспатчит по этому
/// значению в соответствующий виджет.
enum FilterFieldKind {
  /// Обычный чекбокс (style B).
  checkbox,

  /// Скрытый чекбокс без заголовка (style I).
  hiddenCheckbox,

  /// Булевый переключатель с крупной меткой (styleSingle = B1).
  boolean,

  /// Числовое поле цены с суффиксом ₽ (styleSingle = A1).
  price,

  /// Числовое поле без суффикса (styleSingle = G1).
  numericInput,

  /// Универсальное текстовое поле (styles A, A1, H, manual,
  /// либо атрибут без вариантов значений).
  textInput,

  /// Диапазон «от — до» (styles E, E1, либо is_range = true).
  range,

  /// Одиночный выбор через диалог-список.
  singleSelect,

  /// Множественный выбор через dropdown-диалог.
  multipleSelect,

  /// Множественный/одиночный выбор через popup (style F, D/D1 с is_popup).
  multipleSelectPopup,

  /// Группа кнопок-выбора (style C, C1, is_special_design).
  buttonGroup,

  /// Календарь с датами аренды (styleSingle = J1).
  rentTime,

  /// Компактный календарь с датами аренды (styleSingle = K1 или K).
  rentTimeCompact,
}

/// План построения UI-поля: тип виджета и атрибут, который нужно
/// ему передать (возможно с изменёнными флагами через `copyWith`).
class FilterFieldPlan {
  const FilterFieldPlan(this.kind, this.attribute);

  final FilterFieldKind kind;

  /// Атрибут для передачи виджету. Может отличаться от исходного —
  /// резолвер переопределяет `isMultiple`/`isPopup` для F и D1.
  final Attribute attribute;
}

/// Определяет, какой виджет поля построить для переданного атрибута.
///
/// Логика сохранена 1-в-1 из оригинального `_buildDynamicFilter`:
/// сначала идут правила по флагам + `styleSingle` (высший приоритет),
/// затем switch по общему `style`, и наконец fallback для неизвестных
/// стилей.
///
/// Функция чистая: не зависит от виджет-дерева, `BuildContext` или
/// state приложения. Легко тестируется и пригодна для переиспользования
/// в будущем BLoC-слое.
FilterFieldPlan resolveFilterField(Attribute attr) {
  // =================================================================
  // PRIORITY 1: флаги и свойства атрибута
  // Работает для любых новых полей, добавляемых на сервере.
  // =================================================================

  // Скрытые чекбоксы (is_title_hidden + values):
  // приходят ко всем подобным атрибутам, независимо от isMultiple.
  if (attr.isTitleHidden && attr.values.isNotEmpty) {
    return FilterFieldPlan(FilterFieldKind.checkbox, attr);
  }

  // Стили submission-режима — прямая карта по styleSingle.
  switch (attr.styleSingle) {
    case 'A1':
      return FilterFieldPlan(FilterFieldKind.price, attr);
    case 'B1':
      return FilterFieldPlan(FilterFieldKind.boolean, attr);
    case 'G1':
      return FilterFieldPlan(FilterFieldKind.numericInput, attr);
    case 'F':
      // F — это всегда множественный выбор с чекбоксами,
      // даже если в API пришло isMultiple = false.
      return FilterFieldPlan(
        FilterFieldKind.multipleSelectPopup,
        attr.copyWith(isMultiple: true),
      );
    case 'E1':
      return FilterFieldPlan(FilterFieldKind.range, attr);
    case 'J1':
      return FilterFieldPlan(FilterFieldKind.rentTime, attr);
    case 'K1':
    case 'K':
      return FilterFieldPlan(FilterFieldKind.rentTimeCompact, attr);
    case 'C1':
      return FilterFieldPlan(FilterFieldKind.buttonGroup, attr);
  }

  // Простой чекбокс: 1-2 значения, не is_multiple, не скрытый заголовок.
  if (!attr.isMultiple &&
      !attr.isTitleHidden &&
      attr.values.isNotEmpty &&
      attr.values.length <= 2) {
    return FilterFieldPlan(FilterFieldKind.checkbox, attr);
  }

  // Диапазон (is_range).
  if (attr.isRange) {
    return FilterFieldPlan(FilterFieldKind.range, attr);
  }

  // D1 Popup с RADIO (одиночный выбор): несмотря на isMultiple=true в API,
  // D1 показывается как popup с radio-buttons. Override для идентичности.
  final isD1PopupWithoutF =
      (attr.styleSingle == 'D1' || attr.style == 'D') &&
      attr.isMultiple &&
      attr.values.isNotEmpty;
  if (isD1PopupWithoutF) {
    return FilterFieldPlan(
      FilterFieldKind.multipleSelectPopup,
      attr.copyWith(isMultiple: false, isPopup: true),
    );
  }

  // Style D Popup с CHECKBOXES (множественный выбор, не D1).
  if (attr.isPopup &&
      attr.isMultiple &&
      attr.styleSingle != 'D1' &&
      attr.values.isNotEmpty) {
    return FilterFieldPlan(FilterFieldKind.multipleSelectPopup, attr);
  }

  // Группа кнопок (is_special_design).
  if (attr.isSpecialDesign && attr.values.isNotEmpty) {
    return FilterFieldPlan(FilterFieldKind.buttonGroup, attr);
  }

  // Множественный выбор как dropdown (не popup).
  if (attr.isMultiple && !attr.isPopup && attr.values.isNotEmpty) {
    return FilterFieldPlan(FilterFieldKind.multipleSelect, attr);
  }

  // Одиночный выбор: dropdown или popup в зависимости от кол-ва опций.
  if (!attr.isMultiple &&
      !attr.isRange &&
      !attr.isSpecialDesign &&
      attr.values.isNotEmpty) {
    if (attr.values.length > 5) {
      // Много опций → popup с чекбоксами (override isMultiple=true).
      return FilterFieldPlan(
        FilterFieldKind.multipleSelectPopup,
        attr.copyWith(isMultiple: true),
      );
    }
    return FilterFieldPlan(FilterFieldKind.singleSelect, attr);
  }

  // Пустой список значений → текстовое поле (A, H).
  if (attr.values.isEmpty) {
    return FilterFieldPlan(FilterFieldKind.textInput, attr);
  }

  // =================================================================
  // PRIORITY 2: switch по общему style (если ни одно правило выше
  // не сработало).
  // =================================================================
  switch (attr.style) {
    case 'A':
    case 'A1':
    case 'H':
    case 'manual':
      return FilterFieldPlan(FilterFieldKind.textInput, attr);
    case 'B':
      return FilterFieldPlan(FilterFieldKind.checkbox, attr);
    case 'C':
      return FilterFieldPlan(FilterFieldKind.buttonGroup, attr);
    case 'D':
    case 'D1':
      return FilterFieldPlan(
        attr.isPopup
            ? FilterFieldKind.multipleSelectPopup
            : FilterFieldKind.multipleSelect,
        attr,
      );
    case 'E':
    case 'E1':
      return FilterFieldPlan(FilterFieldKind.range, attr);
    case 'F':
      return FilterFieldPlan(FilterFieldKind.multipleSelectPopup, attr);
    case 'G':
    case 'G1':
      return FilterFieldPlan(
        attr.isRange ? FilterFieldKind.range : FilterFieldKind.textInput,
        attr,
      );
    case 'I':
      return FilterFieldPlan(FilterFieldKind.hiddenCheckbox, attr);
  }

  // =================================================================
  // PRIORITY 3: финальный fallback для совсем неизвестных стилей —
  // снова по флагам.
  // =================================================================
  if (attr.isPopup && attr.isMultiple && attr.values.isNotEmpty) {
    return FilterFieldPlan(FilterFieldKind.multipleSelectPopup, attr);
  }
  if (attr.isRange) {
    return FilterFieldPlan(FilterFieldKind.range, attr);
  }
  if (attr.isMultiple && attr.values.isNotEmpty) {
    return FilterFieldPlan(FilterFieldKind.multipleSelect, attr);
  }
  if (attr.values.isNotEmpty) {
    return FilterFieldPlan(FilterFieldKind.buttonGroup, attr);
  }
  return FilterFieldPlan(FilterFieldKind.textInput, attr);
}
