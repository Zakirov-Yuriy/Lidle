// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'filter_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AttributeImpl _$$AttributeImplFromJson(Map<String, dynamic> json) =>
    _$AttributeImpl(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      isFilter: json['is_filter'] as bool? ?? false,
      isRange: json['is_range'] as bool? ?? false,
      isMultiple: json['is_multiple'] as bool? ?? false,
      isHidden: json['is_hidden'] as bool? ?? false,
      isRequired: json['is_required'] as bool? ?? false,
      isTitleHidden: json['is_title_hidden'] as bool? ?? false,
      isSpecialDesign: json['is_special_design'] as bool? ?? false,
      isPopup: json['is_popup'] as bool? ?? false,
      isMaxValue: json['is_max_value'] as bool? ?? false,
      maxValue: json['max_value'],
      vmText: json['vm_text'] as String?,
      dataType: json['data_type'] as String?,
      style: json['style'] as String? ?? '',
      styleSingle: json['style_single'] as String?,
      order: (json['order'] as num?)?.toInt() ?? 0,
      values:
          (json['values'] as List<dynamic>?)
              ?.map((e) => Value.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
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
      'is_popup': instance.isPopup,
      'is_max_value': instance.isMaxValue,
      'max_value': instance.maxValue,
      'vm_text': instance.vmText,
      'data_type': instance.dataType,
      'style': instance.style,
      'style_single': instance.styleSingle,
      'order': instance.order,
      'values': instance.values,
    };

_$ValueImpl _$$ValueImplFromJson(Map<String, dynamic> json) => _$ValueImpl(
  id: (json['id'] as num).toInt(),
  value: json['value'] as String? ?? '',
  order: (json['order'] as num?)?.toInt(),
  maxValue: (json['max_value'] as num?)?.toInt(),
);

Map<String, dynamic> _$$ValueImplToJson(_$ValueImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'value': instance.value,
      'order': instance.order,
      'max_value': instance.maxValue,
    };

_$MetaFiltersResponseImpl _$$MetaFiltersResponseImplFromJson(
  Map<String, dynamic> json,
) => _$MetaFiltersResponseImpl(
  sort: json['sort'] as List<dynamic>,
  filters: (json['filters'] as List<dynamic>)
      .map((e) => Attribute.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$$MetaFiltersResponseImplToJson(
  _$MetaFiltersResponseImpl instance,
) => <String, dynamic>{'sort': instance.sort, 'filters': instance.filters};
