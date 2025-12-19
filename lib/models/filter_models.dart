import 'package:freezed_annotation/freezed_annotation.dart';

part 'filter_models.freezed.dart';
part 'filter_models.g.dart';

@freezed
abstract class Attribute with _$Attribute {
  const factory Attribute({
    required int id,
    required String title,
    @JsonKey(name: 'is_filter') required bool isFilter,
    @JsonKey(name: 'is_range') required bool isRange,
    @JsonKey(name: 'is_multiple') required bool isMultiple,
    @JsonKey(name: 'is_hidden') required bool isHidden,
    @JsonKey(name: 'is_required') required bool isRequired,
    @JsonKey(name: 'is_title_hidden') required bool isTitleHidden,
    @JsonKey(name: 'is_special_design') required bool isSpecialDesign,
    @JsonKey(name: 'data_type') String? dataType,
    required int order,
    required List<Value> values,
  }) = _Attribute;

  factory Attribute.fromJson(Map<String, dynamic> json) =>
      _$AttributeFromJson(json);
}

@freezed
abstract class Value with _$Value {
  const factory Value({
    required int id,
    required String value,
    int? order,
  }) = _Value;

  factory Value.fromJson(Map<String, dynamic> json) => _$ValueFromJson(json);
}
