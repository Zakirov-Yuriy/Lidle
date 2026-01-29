import 'package:json_annotation/json_annotation.dart';

part 'filter_meta_model.g.dart';

/// Модель для ответа /meta/filters
@JsonSerializable()
class FilterMetaResponse {
  final FilterMetaData data;

  FilterMetaResponse({required this.data});

  factory FilterMetaResponse.fromJson(Map<String, dynamic> json) =>
      _$FilterMetaResponseFromJson(json);
  Map<String, dynamic> toJson() => _$FilterMetaResponseToJson(this);
}

@JsonSerializable()
class FilterMetaData {
  /// Доступные варианты сортировки
  final Map<String, String> sort;

  /// Доступные фильтры
  final List<FilterField> filters;

  FilterMetaData({required this.sort, required this.filters});

  factory FilterMetaData.fromJson(Map<String, dynamic> json) =>
      _$FilterMetaDataFromJson(json);
  Map<String, dynamic> toJson() => _$FilterMetaDataToJson(this);
}

@JsonSerializable()
class FilterField {
  final int id;
  final String title;
  final bool is_range;
  final bool is_multiple;
  final bool is_title_hidden;
  final bool is_special_design;
  final bool is_popup;
  final bool is_max_value;
  final String? data_type; // string, integer, numeric, boolean и т.д.
  final String? style;
  final int order;
  final List<FilterValue> values;

  FilterField({
    required this.id,
    required this.title,
    required this.is_range,
    required this.is_multiple,
    required this.is_title_hidden,
    required this.is_special_design,
    required this.is_popup,
    required this.is_max_value,
    this.data_type,
    this.style,
    required this.order,
    required this.values,
  });

  factory FilterField.fromJson(Map<String, dynamic> json) =>
      _$FilterFieldFromJson(json);
  Map<String, dynamic> toJson() => _$FilterFieldToJson(this);
}

@JsonSerializable()
class FilterValue {
  final int id;
  final String value;

  FilterValue({required this.id, required this.value});

  factory FilterValue.fromJson(Map<String, dynamic> json) =>
      _$FilterValueFromJson(json);
  Map<String, dynamic> toJson() => _$FilterValueToJson(this);
}

/// Модель для ответа /content/reports
@JsonSerializable()
class ReportsResponse {
  final bool? success;
  final List<Report> data;

  ReportsResponse({this.success, required this.data});

  factory ReportsResponse.fromJson(Map<String, dynamic> json) =>
      _$ReportsResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ReportsResponseToJson(this);
}

@JsonSerializable()
class Report {
  final int id;
  final String title;

  Report({required this.id, required this.title});

  factory Report.fromJson(Map<String, dynamic> json) => _$ReportFromJson(json);
  Map<String, dynamic> toJson() => _$ReportToJson(this);
}
