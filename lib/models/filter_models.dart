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
    @Default(false) bool isFilter,
    @Default(false) bool isRange,
    @Default(false) bool isMultiple,
    @Default(false) bool isHidden,
    @Default(false) bool isRequired,
    @Default(false) bool isTitleHidden,
    @Default(false) bool isSpecialDesign,
    @Default(false) bool isPopup,
    @Default(false) bool isMaxValue,
    dynamic maxValue,
    String? vmText,
    String? dataType,
    @Default('') String style,
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
    int? maxValue,
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
