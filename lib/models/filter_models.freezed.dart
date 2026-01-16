// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'filter_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Attribute _$AttributeFromJson(Map<String, dynamic> json) {
  return _Attribute.fromJson(json);
}

/// @nodoc
mixin _$Attribute {
  int get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_filter')
  bool get isFilter => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_range')
  bool get isRange => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_multiple')
  bool get isMultiple => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_hidden')
  bool get isHidden => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_required')
  bool get isRequired => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_title_hidden')
  bool get isTitleHidden => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_special_design')
  bool get isSpecialDesign => throw _privateConstructorUsedError;
  @JsonKey(name: 'data_type')
  String? get dataType => throw _privateConstructorUsedError;
  int get order => throw _privateConstructorUsedError;
  List<Value> get values => throw _privateConstructorUsedError;

  /// Serializes this Attribute to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Attribute
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AttributeCopyWith<Attribute> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AttributeCopyWith<$Res> {
  factory $AttributeCopyWith(Attribute value, $Res Function(Attribute) then) =
      _$AttributeCopyWithImpl<$Res, Attribute>;
  @useResult
  $Res call({
    int id,
    String title,
    @JsonKey(name: 'is_filter') bool isFilter,
    @JsonKey(name: 'is_range') bool isRange,
    @JsonKey(name: 'is_multiple') bool isMultiple,
    @JsonKey(name: 'is_hidden') bool isHidden,
    @JsonKey(name: 'is_required') bool isRequired,
    @JsonKey(name: 'is_title_hidden') bool isTitleHidden,
    @JsonKey(name: 'is_special_design') bool isSpecialDesign,
    @JsonKey(name: 'data_type') String? dataType,
    int order,
    List<Value> values,
  });
}

/// @nodoc
class _$AttributeCopyWithImpl<$Res, $Val extends Attribute>
    implements $AttributeCopyWith<$Res> {
  _$AttributeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Attribute
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? isFilter = null,
    Object? isRange = null,
    Object? isMultiple = null,
    Object? isHidden = null,
    Object? isRequired = null,
    Object? isTitleHidden = null,
    Object? isSpecialDesign = null,
    Object? dataType = freezed,
    Object? order = null,
    Object? values = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            isFilter: null == isFilter
                ? _value.isFilter
                : isFilter // ignore: cast_nullable_to_non_nullable
                      as bool,
            isRange: null == isRange
                ? _value.isRange
                : isRange // ignore: cast_nullable_to_non_nullable
                      as bool,
            isMultiple: null == isMultiple
                ? _value.isMultiple
                : isMultiple // ignore: cast_nullable_to_non_nullable
                      as bool,
            isHidden: null == isHidden
                ? _value.isHidden
                : isHidden // ignore: cast_nullable_to_non_nullable
                      as bool,
            isRequired: null == isRequired
                ? _value.isRequired
                : isRequired // ignore: cast_nullable_to_non_nullable
                      as bool,
            isTitleHidden: null == isTitleHidden
                ? _value.isTitleHidden
                : isTitleHidden // ignore: cast_nullable_to_non_nullable
                      as bool,
            isSpecialDesign: null == isSpecialDesign
                ? _value.isSpecialDesign
                : isSpecialDesign // ignore: cast_nullable_to_non_nullable
                      as bool,
            dataType: freezed == dataType
                ? _value.dataType
                : dataType // ignore: cast_nullable_to_non_nullable
                      as String?,
            order: null == order
                ? _value.order
                : order // ignore: cast_nullable_to_non_nullable
                      as int,
            values: null == values
                ? _value.values
                : values // ignore: cast_nullable_to_non_nullable
                      as List<Value>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AttributeImplCopyWith<$Res>
    implements $AttributeCopyWith<$Res> {
  factory _$$AttributeImplCopyWith(
    _$AttributeImpl value,
    $Res Function(_$AttributeImpl) then,
  ) = __$$AttributeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int id,
    String title,
    @JsonKey(name: 'is_filter') bool isFilter,
    @JsonKey(name: 'is_range') bool isRange,
    @JsonKey(name: 'is_multiple') bool isMultiple,
    @JsonKey(name: 'is_hidden') bool isHidden,
    @JsonKey(name: 'is_required') bool isRequired,
    @JsonKey(name: 'is_title_hidden') bool isTitleHidden,
    @JsonKey(name: 'is_special_design') bool isSpecialDesign,
    @JsonKey(name: 'data_type') String? dataType,
    int order,
    List<Value> values,
  });
}

/// @nodoc
class __$$AttributeImplCopyWithImpl<$Res>
    extends _$AttributeCopyWithImpl<$Res, _$AttributeImpl>
    implements _$$AttributeImplCopyWith<$Res> {
  __$$AttributeImplCopyWithImpl(
    _$AttributeImpl _value,
    $Res Function(_$AttributeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Attribute
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? isFilter = null,
    Object? isRange = null,
    Object? isMultiple = null,
    Object? isHidden = null,
    Object? isRequired = null,
    Object? isTitleHidden = null,
    Object? isSpecialDesign = null,
    Object? dataType = freezed,
    Object? order = null,
    Object? values = null,
  }) {
    return _then(
      _$AttributeImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        isFilter: null == isFilter
            ? _value.isFilter
            : isFilter // ignore: cast_nullable_to_non_nullable
                  as bool,
        isRange: null == isRange
            ? _value.isRange
            : isRange // ignore: cast_nullable_to_non_nullable
                  as bool,
        isMultiple: null == isMultiple
            ? _value.isMultiple
            : isMultiple // ignore: cast_nullable_to_non_nullable
                  as bool,
        isHidden: null == isHidden
            ? _value.isHidden
            : isHidden // ignore: cast_nullable_to_non_nullable
                  as bool,
        isRequired: null == isRequired
            ? _value.isRequired
            : isRequired // ignore: cast_nullable_to_non_nullable
                  as bool,
        isTitleHidden: null == isTitleHidden
            ? _value.isTitleHidden
            : isTitleHidden // ignore: cast_nullable_to_non_nullable
                  as bool,
        isSpecialDesign: null == isSpecialDesign
            ? _value.isSpecialDesign
            : isSpecialDesign // ignore: cast_nullable_to_non_nullable
                  as bool,
        dataType: freezed == dataType
            ? _value.dataType
            : dataType // ignore: cast_nullable_to_non_nullable
                  as String?,
        order: null == order
            ? _value.order
            : order // ignore: cast_nullable_to_non_nullable
                  as int,
        values: null == values
            ? _value._values
            : values // ignore: cast_nullable_to_non_nullable
                  as List<Value>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AttributeImpl implements _Attribute {
  const _$AttributeImpl({
    required this.id,
    required this.title,
    @JsonKey(name: 'is_filter') required this.isFilter,
    @JsonKey(name: 'is_range') required this.isRange,
    @JsonKey(name: 'is_multiple') required this.isMultiple,
    @JsonKey(name: 'is_hidden') required this.isHidden,
    @JsonKey(name: 'is_required') required this.isRequired,
    @JsonKey(name: 'is_title_hidden') required this.isTitleHidden,
    @JsonKey(name: 'is_special_design') required this.isSpecialDesign,
    @JsonKey(name: 'data_type') this.dataType,
    required this.order,
    required final List<Value> values,
  }) : _values = values;

  factory _$AttributeImpl.fromJson(Map<String, dynamic> json) =>
      _$$AttributeImplFromJson(json);

  @override
  final int id;
  @override
  final String title;
  @override
  @JsonKey(name: 'is_filter')
  final bool isFilter;
  @override
  @JsonKey(name: 'is_range')
  final bool isRange;
  @override
  @JsonKey(name: 'is_multiple')
  final bool isMultiple;
  @override
  @JsonKey(name: 'is_hidden')
  final bool isHidden;
  @override
  @JsonKey(name: 'is_required')
  final bool isRequired;
  @override
  @JsonKey(name: 'is_title_hidden')
  final bool isTitleHidden;
  @override
  @JsonKey(name: 'is_special_design')
  final bool isSpecialDesign;
  @override
  @JsonKey(name: 'data_type')
  final String? dataType;
  @override
  final int order;
  final List<Value> _values;
  @override
  List<Value> get values {
    if (_values is EqualUnmodifiableListView) return _values;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_values);
  }

  @override
  String toString() {
    return 'Attribute(id: $id, title: $title, isFilter: $isFilter, isRange: $isRange, isMultiple: $isMultiple, isHidden: $isHidden, isRequired: $isRequired, isTitleHidden: $isTitleHidden, isSpecialDesign: $isSpecialDesign, dataType: $dataType, order: $order, values: $values)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AttributeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.isFilter, isFilter) ||
                other.isFilter == isFilter) &&
            (identical(other.isRange, isRange) || other.isRange == isRange) &&
            (identical(other.isMultiple, isMultiple) ||
                other.isMultiple == isMultiple) &&
            (identical(other.isHidden, isHidden) ||
                other.isHidden == isHidden) &&
            (identical(other.isRequired, isRequired) ||
                other.isRequired == isRequired) &&
            (identical(other.isTitleHidden, isTitleHidden) ||
                other.isTitleHidden == isTitleHidden) &&
            (identical(other.isSpecialDesign, isSpecialDesign) ||
                other.isSpecialDesign == isSpecialDesign) &&
            (identical(other.dataType, dataType) ||
                other.dataType == dataType) &&
            (identical(other.order, order) || other.order == order) &&
            const DeepCollectionEquality().equals(other._values, _values));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    title,
    isFilter,
    isRange,
    isMultiple,
    isHidden,
    isRequired,
    isTitleHidden,
    isSpecialDesign,
    dataType,
    order,
    const DeepCollectionEquality().hash(_values),
  );

  /// Create a copy of Attribute
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AttributeImplCopyWith<_$AttributeImpl> get copyWith =>
      __$$AttributeImplCopyWithImpl<_$AttributeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AttributeImplToJson(this);
  }
}

abstract class _Attribute implements Attribute {
  const factory _Attribute({
    required final int id,
    required final String title,
    @JsonKey(name: 'is_filter') required final bool isFilter,
    @JsonKey(name: 'is_range') required final bool isRange,
    @JsonKey(name: 'is_multiple') required final bool isMultiple,
    @JsonKey(name: 'is_hidden') required final bool isHidden,
    @JsonKey(name: 'is_required') required final bool isRequired,
    @JsonKey(name: 'is_title_hidden') required final bool isTitleHidden,
    @JsonKey(name: 'is_special_design') required final bool isSpecialDesign,
    @JsonKey(name: 'data_type') final String? dataType,
    required final int order,
    required final List<Value> values,
  }) = _$AttributeImpl;

  factory _Attribute.fromJson(Map<String, dynamic> json) =
      _$AttributeImpl.fromJson;

  @override
  int get id;
  @override
  String get title;
  @override
  @JsonKey(name: 'is_filter')
  bool get isFilter;
  @override
  @JsonKey(name: 'is_range')
  bool get isRange;
  @override
  @JsonKey(name: 'is_multiple')
  bool get isMultiple;
  @override
  @JsonKey(name: 'is_hidden')
  bool get isHidden;
  @override
  @JsonKey(name: 'is_required')
  bool get isRequired;
  @override
  @JsonKey(name: 'is_title_hidden')
  bool get isTitleHidden;
  @override
  @JsonKey(name: 'is_special_design')
  bool get isSpecialDesign;
  @override
  @JsonKey(name: 'data_type')
  String? get dataType;
  @override
  int get order;
  @override
  List<Value> get values;

  /// Create a copy of Attribute
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AttributeImplCopyWith<_$AttributeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Value _$ValueFromJson(Map<String, dynamic> json) {
  return _Value.fromJson(json);
}

/// @nodoc
mixin _$Value {
  int get id => throw _privateConstructorUsedError;
  String get value => throw _privateConstructorUsedError;
  int? get order => throw _privateConstructorUsedError;

  /// Serializes this Value to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Value
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ValueCopyWith<Value> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ValueCopyWith<$Res> {
  factory $ValueCopyWith(Value value, $Res Function(Value) then) =
      _$ValueCopyWithImpl<$Res, Value>;
  @useResult
  $Res call({int id, String value, int? order});
}

/// @nodoc
class _$ValueCopyWithImpl<$Res, $Val extends Value>
    implements $ValueCopyWith<$Res> {
  _$ValueCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Value
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? value = null,
    Object? order = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            value: null == value
                ? _value.value
                : value // ignore: cast_nullable_to_non_nullable
                      as String,
            order: freezed == order
                ? _value.order
                : order // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ValueImplCopyWith<$Res> implements $ValueCopyWith<$Res> {
  factory _$$ValueImplCopyWith(
    _$ValueImpl value,
    $Res Function(_$ValueImpl) then,
  ) = __$$ValueImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int id, String value, int? order});
}

/// @nodoc
class __$$ValueImplCopyWithImpl<$Res>
    extends _$ValueCopyWithImpl<$Res, _$ValueImpl>
    implements _$$ValueImplCopyWith<$Res> {
  __$$ValueImplCopyWithImpl(
    _$ValueImpl _value,
    $Res Function(_$ValueImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Value
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? value = null,
    Object? order = freezed,
  }) {
    return _then(
      _$ValueImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        value: null == value
            ? _value.value
            : value // ignore: cast_nullable_to_non_nullable
                  as String,
        order: freezed == order
            ? _value.order
            : order // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ValueImpl implements _Value {
  const _$ValueImpl({required this.id, required this.value, this.order});

  factory _$ValueImpl.fromJson(Map<String, dynamic> json) =>
      _$$ValueImplFromJson(json);

  @override
  final int id;
  @override
  final String value;
  @override
  final int? order;

  @override
  String toString() {
    return 'Value(id: $id, value: $value, order: $order)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ValueImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.order, order) || other.order == order));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, value, order);

  /// Create a copy of Value
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ValueImplCopyWith<_$ValueImpl> get copyWith =>
      __$$ValueImplCopyWithImpl<_$ValueImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ValueImplToJson(this);
  }
}

abstract class _Value implements Value {
  const factory _Value({
    required final int id,
    required final String value,
    final int? order,
  }) = _$ValueImpl;

  factory _Value.fromJson(Map<String, dynamic> json) = _$ValueImpl.fromJson;

  @override
  int get id;
  @override
  String get value;
  @override
  int? get order;

  /// Create a copy of Value
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ValueImplCopyWith<_$ValueImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MetaFiltersResponse _$MetaFiltersResponseFromJson(Map<String, dynamic> json) {
  return _MetaFiltersResponse.fromJson(json);
}

/// @nodoc
mixin _$MetaFiltersResponse {
  Map<String, String> get sort => throw _privateConstructorUsedError;
  List<Attribute> get filters => throw _privateConstructorUsedError;

  /// Serializes this MetaFiltersResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MetaFiltersResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MetaFiltersResponseCopyWith<MetaFiltersResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MetaFiltersResponseCopyWith<$Res> {
  factory $MetaFiltersResponseCopyWith(
    MetaFiltersResponse value,
    $Res Function(MetaFiltersResponse) then,
  ) = _$MetaFiltersResponseCopyWithImpl<$Res, MetaFiltersResponse>;
  @useResult
  $Res call({Map<String, String> sort, List<Attribute> filters});
}

/// @nodoc
class _$MetaFiltersResponseCopyWithImpl<$Res, $Val extends MetaFiltersResponse>
    implements $MetaFiltersResponseCopyWith<$Res> {
  _$MetaFiltersResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MetaFiltersResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? sort = null, Object? filters = null}) {
    return _then(
      _value.copyWith(
            sort: null == sort
                ? _value.sort
                : sort // ignore: cast_nullable_to_non_nullable
                      as Map<String, String>,
            filters: null == filters
                ? _value.filters
                : filters // ignore: cast_nullable_to_non_nullable
                      as List<Attribute>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MetaFiltersResponseImplCopyWith<$Res>
    implements $MetaFiltersResponseCopyWith<$Res> {
  factory _$$MetaFiltersResponseImplCopyWith(
    _$MetaFiltersResponseImpl value,
    $Res Function(_$MetaFiltersResponseImpl) then,
  ) = __$$MetaFiltersResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({Map<String, String> sort, List<Attribute> filters});
}

/// @nodoc
class __$$MetaFiltersResponseImplCopyWithImpl<$Res>
    extends _$MetaFiltersResponseCopyWithImpl<$Res, _$MetaFiltersResponseImpl>
    implements _$$MetaFiltersResponseImplCopyWith<$Res> {
  __$$MetaFiltersResponseImplCopyWithImpl(
    _$MetaFiltersResponseImpl _value,
    $Res Function(_$MetaFiltersResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MetaFiltersResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? sort = null, Object? filters = null}) {
    return _then(
      _$MetaFiltersResponseImpl(
        sort: null == sort
            ? _value._sort
            : sort // ignore: cast_nullable_to_non_nullable
                  as Map<String, String>,
        filters: null == filters
            ? _value._filters
            : filters // ignore: cast_nullable_to_non_nullable
                  as List<Attribute>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MetaFiltersResponseImpl implements _MetaFiltersResponse {
  const _$MetaFiltersResponseImpl({
    required final Map<String, String> sort,
    required final List<Attribute> filters,
  }) : _sort = sort,
       _filters = filters;

  factory _$MetaFiltersResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$MetaFiltersResponseImplFromJson(json);

  final Map<String, String> _sort;
  @override
  Map<String, String> get sort {
    if (_sort is EqualUnmodifiableMapView) return _sort;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_sort);
  }

  final List<Attribute> _filters;
  @override
  List<Attribute> get filters {
    if (_filters is EqualUnmodifiableListView) return _filters;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_filters);
  }

  @override
  String toString() {
    return 'MetaFiltersResponse(sort: $sort, filters: $filters)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MetaFiltersResponseImpl &&
            const DeepCollectionEquality().equals(other._sort, _sort) &&
            const DeepCollectionEquality().equals(other._filters, _filters));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_sort),
    const DeepCollectionEquality().hash(_filters),
  );

  /// Create a copy of MetaFiltersResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MetaFiltersResponseImplCopyWith<_$MetaFiltersResponseImpl> get copyWith =>
      __$$MetaFiltersResponseImplCopyWithImpl<_$MetaFiltersResponseImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$MetaFiltersResponseImplToJson(this);
  }
}

abstract class _MetaFiltersResponse implements MetaFiltersResponse {
  const factory _MetaFiltersResponse({
    required final Map<String, String> sort,
    required final List<Attribute> filters,
  }) = _$MetaFiltersResponseImpl;

  factory _MetaFiltersResponse.fromJson(Map<String, dynamic> json) =
      _$MetaFiltersResponseImpl.fromJson;

  @override
  Map<String, String> get sort;
  @override
  List<Attribute> get filters;

  /// Create a copy of MetaFiltersResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MetaFiltersResponseImplCopyWith<_$MetaFiltersResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
