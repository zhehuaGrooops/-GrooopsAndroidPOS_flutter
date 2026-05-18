import 'package:admin_desktop/src/models/data/table_data.dart';
import 'package:admin_desktop/src/models/response/product_calculate_response.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../../../models/models.dart';

part 'right_side_state.freezed.dart';

@freezed
class RightSideState with _$RightSideState {
  const factory RightSideState({
    @Default(false) bool isBagsLoading,
    @Default(false) bool isUsersLoading,
    @Default(false) bool isSectionLoading,
    @Default(false) bool isTableLoading,
    @Default(false) bool isUserDetailsLoading,
    @Default(false) bool isCurrenciesLoading,
    @Default(false) bool isPaymentsLoading,
    @Default(false) bool isProductCalculateLoading,
    @Default(false) bool isButtonLoading,
    @Default(false) bool isActive,
    @Default(false) bool isOrderLoading,
    @Default(false) bool isPromoCodeLoading,
    @Default(false) bool isLogoImageLoading,
    @Default(false) bool isBackImageLoading,
    @Default([]) List<BagData> bags,
    @Default([]) List<UserData> users,
    @Default([]) List<TableData> tables,
    @Default([]) List<ShopSection> sections,
    @Default([]) List<DropDownItemData> dropdownUsers,
    @Default([]) List<AddressData> userAddresses,
    @Default([]) List<CurrencyData> currencies,
    @Default([]) List<PaymentData> payments,
    @Default(0) int selectedBagIndex,
    @Default(0) double subtotal,
    @Default(0) double productTax,
    @Default(0) double shopTax,
    @Default('') String usersQuery,
    @Default('') String tableQuery,
    @Default('') String sectionQuery,
    @Default('') String orderType,
    @Default('') String calculate,
    @Default('') String tempCalculate,
    @Default('') String manualBillDiscountText,
    @Default(false) bool isCalculateConfirmed,
    @Default('') String comment,
    @Default(null) String? selectUserError,
    @Default(null) String? selectAddressError,
    @Default(null) String? selectCurrencyError,
    @Default(null) String? selectPaymentError,
    @Default(null) String? selectSectionError,
    @Default(null) String? selectTableError,
    @Default(null) String? coupon,
    @Default(null) DateTime? orderDate,
    @Default(null) TimeOfDay? orderTime,
    @Default({}) Map<int, num> tierPrices,
    UserData? selectedUser,
    ShopSection? selectedSection,
    TableData? selectedTable,
    AddressData? selectedAddress,
    CurrencyData? selectedCurrency,
    PaymentData? selectedPayment,
    PriceDate? paginateResponse,
    @Default(null) DiscountSetting? selectedBillDiscount,
  }) = _RightSideState;

  const RightSideState._();
}
