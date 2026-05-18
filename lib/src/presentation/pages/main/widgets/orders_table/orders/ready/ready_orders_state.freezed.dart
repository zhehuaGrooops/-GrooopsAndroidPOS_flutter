// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ready_orders_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ReadyOrdersState {
  bool get isLoading => throw _privateConstructorUsedError;
  bool get hasMore => throw _privateConstructorUsedError;
  List<OrderData> get orders => throw _privateConstructorUsedError;
  int get totalCount => throw _privateConstructorUsedError;
  String get query => throw _privateConstructorUsedError;

  /// Create a copy of ReadyOrdersState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReadyOrdersStateCopyWith<ReadyOrdersState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReadyOrdersStateCopyWith<$Res> {
  factory $ReadyOrdersStateCopyWith(
          ReadyOrdersState value, $Res Function(ReadyOrdersState) then) =
      _$ReadyOrdersStateCopyWithImpl<$Res, ReadyOrdersState>;
  @useResult
  $Res call(
      {bool isLoading,
      bool hasMore,
      List<OrderData> orders,
      int totalCount,
      String query});
}

/// @nodoc
class _$ReadyOrdersStateCopyWithImpl<$Res, $Val extends ReadyOrdersState>
    implements $ReadyOrdersStateCopyWith<$Res> {
  _$ReadyOrdersStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReadyOrdersState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isLoading = null,
    Object? hasMore = null,
    Object? orders = null,
    Object? totalCount = null,
    Object? query = null,
  }) {
    return _then(_value.copyWith(
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      hasMore: null == hasMore
          ? _value.hasMore
          : hasMore // ignore: cast_nullable_to_non_nullable
              as bool,
      orders: null == orders
          ? _value.orders
          : orders // ignore: cast_nullable_to_non_nullable
              as List<OrderData>,
      totalCount: null == totalCount
          ? _value.totalCount
          : totalCount // ignore: cast_nullable_to_non_nullable
              as int,
      query: null == query
          ? _value.query
          : query // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ReadyOrdersStateImplCopyWith<$Res>
    implements $ReadyOrdersStateCopyWith<$Res> {
  factory _$$ReadyOrdersStateImplCopyWith(_$ReadyOrdersStateImpl value,
          $Res Function(_$ReadyOrdersStateImpl) then) =
      __$$ReadyOrdersStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool isLoading,
      bool hasMore,
      List<OrderData> orders,
      int totalCount,
      String query});
}

/// @nodoc
class __$$ReadyOrdersStateImplCopyWithImpl<$Res>
    extends _$ReadyOrdersStateCopyWithImpl<$Res, _$ReadyOrdersStateImpl>
    implements _$$ReadyOrdersStateImplCopyWith<$Res> {
  __$$ReadyOrdersStateImplCopyWithImpl(_$ReadyOrdersStateImpl _value,
      $Res Function(_$ReadyOrdersStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of ReadyOrdersState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isLoading = null,
    Object? hasMore = null,
    Object? orders = null,
    Object? totalCount = null,
    Object? query = null,
  }) {
    return _then(_$ReadyOrdersStateImpl(
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      hasMore: null == hasMore
          ? _value.hasMore
          : hasMore // ignore: cast_nullable_to_non_nullable
              as bool,
      orders: null == orders
          ? _value._orders
          : orders // ignore: cast_nullable_to_non_nullable
              as List<OrderData>,
      totalCount: null == totalCount
          ? _value.totalCount
          : totalCount // ignore: cast_nullable_to_non_nullable
              as int,
      query: null == query
          ? _value.query
          : query // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$ReadyOrdersStateImpl extends _ReadyOrdersState {
  const _$ReadyOrdersStateImpl(
      {this.isLoading = false,
      this.hasMore = true,
      final List<OrderData> orders = const [],
      this.totalCount = 0,
      this.query = ''})
      : _orders = orders,
        super._();

  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final bool hasMore;
  final List<OrderData> _orders;
  @override
  @JsonKey()
  List<OrderData> get orders {
    if (_orders is EqualUnmodifiableListView) return _orders;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_orders);
  }

  @override
  @JsonKey()
  final int totalCount;
  @override
  @JsonKey()
  final String query;

  @override
  String toString() {
    return 'ReadyOrdersState(isLoading: $isLoading, hasMore: $hasMore, orders: $orders, totalCount: $totalCount, query: $query)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReadyOrdersStateImpl &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.hasMore, hasMore) || other.hasMore == hasMore) &&
            const DeepCollectionEquality().equals(other._orders, _orders) &&
            (identical(other.totalCount, totalCount) ||
                other.totalCount == totalCount) &&
            (identical(other.query, query) || other.query == query));
  }

  @override
  int get hashCode => Object.hash(runtimeType, isLoading, hasMore,
      const DeepCollectionEquality().hash(_orders), totalCount, query);

  /// Create a copy of ReadyOrdersState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReadyOrdersStateImplCopyWith<_$ReadyOrdersStateImpl> get copyWith =>
      __$$ReadyOrdersStateImplCopyWithImpl<_$ReadyOrdersStateImpl>(
          this, _$identity);
}

abstract class _ReadyOrdersState extends ReadyOrdersState {
  const factory _ReadyOrdersState(
      {final bool isLoading,
      final bool hasMore,
      final List<OrderData> orders,
      final int totalCount,
      final String query}) = _$ReadyOrdersStateImpl;
  const _ReadyOrdersState._() : super._();

  @override
  bool get isLoading;
  @override
  bool get hasMore;
  @override
  List<OrderData> get orders;
  @override
  int get totalCount;
  @override
  String get query;

  /// Create a copy of ReadyOrdersState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReadyOrdersStateImplCopyWith<_$ReadyOrdersStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
