import 'package:freezed_annotation/freezed_annotation.dart';

part 'filter_models.freezed.dart';
part 'filter_models.g.dart';

/// Модель атрибута фильтра для создания объявления
///
/// API может возвращать order как null, поэтому используем @Default(0)
/// Все поля имеют значения по умолчанию для безопасного парсинга
@freezed
class Attribute with _$Attribute {
  const factory Attribute({
    required int id,
    @Default('') String title,
    @JsonKey(name: 'is_filter') @Default(false) bool isFilter,
    @JsonKey(name: 'is_range') @Default(false) bool isRange,
    @JsonKey(name: 'is_multiple') @Default(false) bool isMultiple,
    @JsonKey(name: 'is_hidden') @Default(false) bool isHidden,
    @JsonKey(name: 'is_required') @Default(false) bool isRequired,
    @JsonKey(name: 'is_title_hidden') @Default(false) bool isTitleHidden,
    @JsonKey(name: 'is_special_design') @Default(false) bool isSpecialDesign,
    @JsonKey(name: 'is_popup') @Default(false) bool isPopup,
    @JsonKey(name: 'is_max_value') @Default(false) bool isMaxValue,
    @JsonKey(name: 'max_value') dynamic maxValue,
    @JsonKey(name: 'vm_text') String? vmText,
    @JsonKey(name: 'data_type') String? dataType,
    @Default('') String style,
    @JsonKey(name: 'style_single') String? styleSingle,
    @Default('') String style2, // Преобразованный стиль для подачи объявления
    @Default(0) int order, // API может возвращать null, используем default
    @Default([]) List<Value> values,
  }) = _Attribute;

  factory Attribute.fromJson(Map<String, dynamic> json) =>
      _$AttributeFromJson(json);
}

/// Модель значения атрибута фильтра
@freezed
class Value with _$Value {
  const factory Value({
    required int id,
    @Default('') String value,
    int? order,
    @JsonKey(name: 'max_value') int? maxValue,
  }) = _Value;

  factory Value.fromJson(Map<String, dynamic> json) => _$ValueFromJson(json);
}

/// Модель ответа API с фильтрами
@freezed
class MetaFiltersResponse with _$MetaFiltersResponse {
  const factory MetaFiltersResponse({
    required List<dynamic> sort,
    required List<Attribute> filters,
  }) = _MetaFiltersResponse;

  factory MetaFiltersResponse.fromJson(Map<String, dynamic> json) =>
      _$MetaFiltersResponseFromJson(json);
}
