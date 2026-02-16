// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'filter_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AttributeImpl _$$AttributeImplFromJson(Map<String, dynamic> json) =>
    _$AttributeImpl(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      isFilter: json['isFilter'] as bool? ?? false,
      isRange: json['isRange'] as bool? ?? false,
      isMultiple: json['isMultiple'] as bool? ?? false,
      isHidden: json['isHidden'] as bool? ?? false,
      isRequired: json['isRequired'] as bool? ?? false,
      isTitleHidden: json['isTitleHidden'] as bool? ?? false,
      isSpecialDesign: json['isSpecialDesign'] as bool? ?? false,
      isPopup: json['isPopup'] as bool? ?? false,
      isMaxValue: json['isMaxValue'] as bool? ?? false,
      maxValue: json['maxValue'],
      vmText: json['vmText'] as String?,
      dataType: json['dataType'] as String?,
      style: json['style'] as String? ?? '',
      order: (json['order'] as num).toInt(),
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
      'isFilter': instance.isFilter,
      'isRange': instance.isRange,
      'isMultiple': instance.isMultiple,
      'isHidden': instance.isHidden,
      'isRequired': instance.isRequired,
      'isTitleHidden': instance.isTitleHidden,
      'isSpecialDesign': instance.isSpecialDesign,
      'isPopup': instance.isPopup,
      'isMaxValue': instance.isMaxValue,
      'maxValue': instance.maxValue,
      'vmText': instance.vmText,
      'dataType': instance.dataType,
      'style': instance.style,
      'order': instance.order,
      'values': instance.values,
    };

_$ValueImpl _$$ValueImplFromJson(Map<String, dynamic> json) => _$ValueImpl(
  id: (json['id'] as num).toInt(),
  value: json['value'] as String? ?? '',
  order: (json['order'] as num?)?.toInt(),
  maxValue: (json['maxValue'] as num?)?.toInt(),
);

Map<String, dynamic> _$$ValueImplToJson(_$ValueImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'value': instance.value,
      'order': instance.order,
      'maxValue': instance.maxValue,
    };
