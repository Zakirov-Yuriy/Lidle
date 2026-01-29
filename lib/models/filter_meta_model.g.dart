// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'filter_meta_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FilterMetaResponse _$FilterMetaResponseFromJson(Map<String, dynamic> json) =>
    FilterMetaResponse(
      data: FilterMetaData.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$FilterMetaResponseToJson(FilterMetaResponse instance) =>
    <String, dynamic>{'data': instance.data};

FilterMetaData _$FilterMetaDataFromJson(Map<String, dynamic> json) =>
    FilterMetaData(
      sort: Map<String, String>.from(json['sort'] as Map),
      filters: (json['filters'] as List<dynamic>)
          .map((e) => FilterField.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$FilterMetaDataToJson(FilterMetaData instance) =>
    <String, dynamic>{'sort': instance.sort, 'filters': instance.filters};

FilterField _$FilterFieldFromJson(Map<String, dynamic> json) => FilterField(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  is_range: json['is_range'] as bool,
  is_multiple: json['is_multiple'] as bool,
  is_title_hidden: json['is_title_hidden'] as bool,
  is_special_design: json['is_special_design'] as bool,
  is_popup: json['is_popup'] as bool,
  is_max_value: json['is_max_value'] as bool,
  data_type: json['data_type'] as String?,
  style: json['style'] as String?,
  order: (json['order'] as num).toInt(),
  values: (json['values'] as List<dynamic>)
      .map((e) => FilterValue.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$FilterFieldToJson(FilterField instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'is_range': instance.is_range,
      'is_multiple': instance.is_multiple,
      'is_title_hidden': instance.is_title_hidden,
      'is_special_design': instance.is_special_design,
      'is_popup': instance.is_popup,
      'is_max_value': instance.is_max_value,
      'data_type': instance.data_type,
      'style': instance.style,
      'order': instance.order,
      'values': instance.values,
    };

FilterValue _$FilterValueFromJson(Map<String, dynamic> json) => FilterValue(
  id: (json['id'] as num).toInt(),
  value: json['value'] as String,
);

Map<String, dynamic> _$FilterValueToJson(FilterValue instance) =>
    <String, dynamic>{'id': instance.id, 'value': instance.value};

ReportsResponse _$ReportsResponseFromJson(Map<String, dynamic> json) =>
    ReportsResponse(
      success: json['success'] as bool?,
      data: (json['data'] as List<dynamic>)
          .map((e) => Report.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ReportsResponseToJson(ReportsResponse instance) =>
    <String, dynamic>{'success': instance.success, 'data': instance.data};

Report _$ReportFromJson(Map<String, dynamic> json) =>
    Report(id: (json['id'] as num).toInt(), title: json['title'] as String);

Map<String, dynamic> _$ReportToJson(Report instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
};
