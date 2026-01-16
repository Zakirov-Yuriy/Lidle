// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'filter_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AttributeImpl _$$AttributeImplFromJson(Map<String, dynamic> json) =>
    _$AttributeImpl(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      isFilter: json['is_filter'] as bool,
      isRange: json['is_range'] as bool,
      isMultiple: json['is_multiple'] as bool,
      isHidden: json['is_hidden'] as bool,
      isRequired: json['is_required'] as bool,
      isTitleHidden: json['is_title_hidden'] as bool,
      isSpecialDesign: json['is_special_design'] as bool,
      dataType: json['data_type'] as String?,
      order: (json['order'] as num).toInt(),
      values: (json['values'] as List<dynamic>)
          .map((e) => Value.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$AttributeImplToJson(_$AttributeImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'is_filter': instance.isFilter,
      'is_range': instance.isRange,
      'is_multiple': instance.isMultiple,
      'is_hidden': instance.isHidden,
      'is_required': instance.isRequired,
      'is_title_hidden': instance.isTitleHidden,
      'is_special_design': instance.isSpecialDesign,
      'data_type': instance.dataType,
      'order': instance.order,
      'values': instance.values,
    };

_$ValueImpl _$$ValueImplFromJson(Map<String, dynamic> json) => _$ValueImpl(
  id: (json['id'] as num).toInt(),
  value: json['value'] as String,
  order: (json['order'] as num?)?.toInt(),
);

Map<String, dynamic> _$$ValueImplToJson(_$ValueImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'value': instance.value,
      'order': instance.order,
    };

_$MetaFiltersResponseImpl _$$MetaFiltersResponseImplFromJson(
  Map<String, dynamic> json,
) => _$MetaFiltersResponseImpl(
  sort: Map<String, String>.from(json['sort'] as Map),
  filters: (json['filters'] as List<dynamic>)
      .map((e) => Attribute.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$$MetaFiltersResponseImplToJson(
  _$MetaFiltersResponseImpl instance,
) => <String, dynamic>{'sort': instance.sort, 'filters': instance.filters};
