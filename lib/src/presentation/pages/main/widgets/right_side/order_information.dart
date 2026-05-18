// ignore_for_file: must_be_immutable

import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:admin_desktop/src/core/utils/app_helpers.dart';
import 'package:admin_desktop/src/core/utils/app_validators.dart';
import 'package:admin_desktop/src/core/utils/local_storage.dart';
import 'package:admin_desktop/src/models/models.dart';
import 'package:admin_desktop/src/presentation/components/buttons/animation_button_effect.dart';
import 'package:admin_desktop/src/presentation/components/components.dart';
import 'package:admin_desktop/src/presentation/components/text_fields/custom_textformfield.dart';

import 'package:admin_desktop/src/presentation/pages/main/riverpod/provider/main_provider.dart';
import 'package:admin_desktop/src/presentation/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'riverpod/right_side_provider.dart';
import 'riverpod/right_side_state.dart';

class OrderInformation extends ConsumerWidget {
  // optional override for the subtotal shown in the modal (e.g. client-side calculated total)
  // final num? initialSubtotal;

  final num subtotal;
  final num totalDiscount;
  final num finalTotal;

  OrderInformation({
    super.key,
    // UPDATE the constructor
    required this.subtotal,
    required this.totalDiscount,
    required this.finalTotal,
  });

  // kept as minimal placeholder: actual options are built dynamically from product.category.service_types
  List listOfType = [];

  List listDine = [TrKeys.dine];

  final formKey = GlobalKey<FormState>();

  List _buildShippingOptionsFromState(RightSideState state) {
    // Try to read service_types from the first product's category
    List<String> names = [];
    try {
      final stocks = state.paginateResponse?.stocks;
      if (stocks != null && stocks.isNotEmpty) {
        final category = stocks.first.category;
        // Support different naming conventions in generated models: serviceTypes or service_types
        final serviceTypes = (category == null)
            ? null
            : ( // try a few common shapes defensively
                (category as dynamic).serviceTypes ??
                    (category as dynamic).service_types);

        if (serviceTypes is List && serviceTypes.isNotEmpty) {
          for (final st in serviceTypes) {
            if (st == null) continue;
            if (st is String) {
              names.add(st);
            } else if (st is Map) {
              names.add((st['name'] ?? '').toString());
            } else {
              // try reading name property from an object
              try {
                names.add(((st as dynamic).name ?? '').toString());
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}

    // fallback to previous defaults
    if (names.isEmpty) {
      names = [
        TrKeys.delivery,
        TrKeys.pickup,
        TrKeys.dine,
        TrKeys.grab,
        TrKeys.food,
      ].map((e) => e.toString()).toList();
    }

    // Map the API service type names to the app's internal keys/labels (TrKeys)
    return names.map((name) {
      final lower = name.toLowerCase();
      if (lower.contains('dine')) return TrKeys.dine;
      if (lower.contains('delivery')) return TrKeys.delivery;
      if (lower.contains('take') ||
          lower.contains('takeaway') ||
          lower.contains('take away')) {
        return TrKeys.pickup;
      }
      if (lower.contains('grab')) return TrKeys.grab;
      if (lower.contains('panda')) return TrKeys.food;
      return name; // unknown -> show raw name
    }).toList();
  }

  @override
  Widget build(BuildContext context, ref) {
    final notifier = ref.read(rightSideProvider.notifier);
    final state = ref.watch(rightSideProvider);
    final BagData bag = state.bags[state.selectedBagIndex];
    final shippingOptions = _buildShippingOptionsFromState(state);
    final globalSettings = LocalStorage.getSettingsList();
    final bool hideTable = globalSettings
            .firstWhere((element) => element.key == 'hide_table',
                orElse: () => SettingsData(value: '0'))
            .value ==
        '1';

    return KeyboardDismisser(
      child: Container(
        width: MediaQuery.of(context).size.width / 2,
        padding: REdgeInsets.symmetric(horizontal: 24.r),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.r),
          color: AppStyle.white,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    AppHelpers.getTranslation(TrKeys.order),
                    style: GoogleFonts.inter(
                        fontSize: 22.r, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                      onPressed: context.maybePop,
                      icon: const Icon(FlutterRemix.close_line))
                ],
              ),
              16.verticalSpace,
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (state.orderType == TrKeys.dine && !hideTable)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: AppStyle.unselectedBottomBarBack,
                                    width: 1.r,
                                  ),
                                ),
                                alignment: Alignment.center,
                                height: 56.r,
                                padding: EdgeInsets.only(left: 16.r),
                                child: CustomDropdown(
                                  hintText: AppHelpers.getTranslation(
                                      TrKeys.selectSection),
                                  searchHintText:
                                      AppHelpers.getTranslation(TrKeys.search),
                                  dropDownType: DropDownType.section,
                                  onChanged: (value) =>
                                      notifier.setSectionQuery(context, value),
                                  initialValue:
                                      bag.selectedSection?.translation?.title ??
                                          (state.sections.isNotEmpty
                                              ? state.sections.first.translation
                                                  ?.title
                                              : ''),
                                ),
                              ),
                              Visibility(
                                visible: state.selectSectionError != null,
                                child: Padding(
                                  padding: EdgeInsets.only(top: 6.r, left: 4.r),
                                  child: Text(
                                    AppHelpers.getTranslation(
                                        state.selectSectionError ?? ""),
                                    style: GoogleFonts.inter(
                                        color: AppStyle.red, fontSize: 14.sp),
                                  ),
                                ),
                              ),
                              24.verticalSpace,
                            ],
                          ),
                        // PopupMenuButton<int>(
                        //   enabled: bag.selectedCurrency ==
                        //       null, // disable when already preset
                        //   itemBuilder: (context) {
                        //     return state.currencies
                        //         .map(
                        //           (currency) => PopupMenuItem<int>(
                        //             value: currency.id,
                        //             child: Text(
                        //               '${currency.title}(${currency.symbol})',
                        //               style: GoogleFonts.inter(
                        //                 fontWeight: FontWeight.w500,
                        //                 fontSize: 14.sp,
                        //                 color: AppStyle.black,
                        //                 letterSpacing: -14 * 0.02,
                        //               ),
                        //             ),
                        //           ),
                        //         )
                        //         .toList();
                        //   },
                        //   onSelected: notifier.setSelectedCurrency,
                        //   shape: RoundedRectangleBorder(
                        //     borderRadius: BorderRadius.circular(10.r),
                        //   ),
                        //   color: AppStyle.white,
                        //   elevation: 10,
                        //   child: SelectFromButton(
                        //     title: state.selectedCurrency?.title ??
                        //         AppHelpers.getTranslation(
                        //             TrKeys.selectCurrency),
                        //   ),
                        // ),
                        // Visibility(
                        //   visible: state.selectCurrencyError != null,
                        //   child: Padding(
                        //     padding: EdgeInsets.only(top: 6.r, left: 4.r),
                        //     child: Text(
                        //       AppHelpers.getTranslation(
                        //           state.selectCurrencyError ?? ""),
                        //       style: GoogleFonts.inter(
                        //           color: AppStyle.red, fontSize: 14.sp),
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                  16.horizontalSpace,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (state.orderType == TrKeys.dine && !hideTable)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: AppStyle.unselectedBottomBarBack,
                                    width: 1.r,
                                  ),
                                ),
                                alignment: Alignment.center,
                                height: 56.r,
                                padding: EdgeInsets.only(left: 16.r),
                                child: CustomDropdown(
                                  hintText: AppHelpers.getTranslation(
                                      TrKeys.selectTable),
                                  searchHintText:
                                      AppHelpers.getTranslation(TrKeys.search),
                                  dropDownType: DropDownType.table,
                                  onChanged: (value) =>
                                      notifier.setTableQuery(context, value),
                                  initialValue: bag.selectedTable?.name ?? '',
                                ),
                              ),
                              Visibility(
                                visible: state.selectTableError != null,
                                child: Padding(
                                  padding: EdgeInsets.only(top: 6.r, left: 4.r),
                                  child: Text(
                                    AppHelpers.getTranslation(
                                        state.selectTableError ?? ""),
                                    style: GoogleFonts.inter(
                                        color: AppStyle.red, fontSize: 14.sp),
                                  ),
                                ),
                              ),
                              24.verticalSpace,
                            ],
                          ),
                        // PopupMenuButton<int>(
                        //   initialValue: state.selectedPayment?.id,
                        //   itemBuilder: (context) {
                        //     return state.payments
                        //         .map(
                        //           (payment) => PopupMenuItem<int>(
                        //             value: payment.id,
                        //             child: Text(
                        //               AppHelpers.getTranslation(
                        //                   payment.tag ?? ""),
                        //               style: GoogleFonts.inter(
                        //                 fontWeight: FontWeight.w500,
                        //                 fontSize: 14.sp,
                        //                 color: AppStyle.black,
                        //                 letterSpacing: -14 * 0.02,
                        //               ),
                        //             ),
                        //           ),
                        //         )
                        //         .toList();
                        //   },
                        //   onSelected: notifier.setSelectedPayment,
                        //   shape: RoundedRectangleBorder(
                        //     borderRadius: BorderRadius.circular(10.r),
                        //   ),
                        //   color: AppStyle.white,
                        //   elevation: 10,
                        //   child: SelectFromButton(
                        //     title: AppHelpers.getTranslation(
                        //         state.selectedPayment?.tag ??
                        //             TrKeys.selectPayment),
                        //   ),
                        // ),
                        // Visibility(
                        //   visible: state.selectPaymentError != null,
                        //   child: Padding(
                        //     padding: EdgeInsets.only(top: 6.r, left: 4.r),
                        //     child: Text(
                        //       AppHelpers.getTranslation(
                        //           state.selectPaymentError ?? ""),
                        //       style: GoogleFonts.inter(
                        //           color: AppStyle.red, fontSize: 14.sp),
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                ],
              ),
              16.verticalSpace,
              if (AppHelpers.isNumberRequiredToOrder() &&
                  state.selectedUser != null &&
                  (state.selectedUser?.phone?.isEmpty ?? true))
                Form(
                  key: formKey,
                  child: Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          inputType: TextInputType.phone,
                          validator: (value) {
                            return AppValidators.emptyCheck(value);
                          },
                          onChanged: (p0) {
                            notifier.setPhone(p0);
                          },
                          label: AppHelpers.getTranslation(TrKeys.phoneNumber),
                        ),
                      ),
                    ],
                  ),
                ),
              12.verticalSpace,
              const Divider(),
              12.verticalSpace,
              Text(
                AppHelpers.getTranslation(TrKeys.shippingInformation),
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, fontSize: 22.r),
              ),
              16.verticalSpace,
              Row(
                children: [
                  ...(LocalStorage.getUser()?.role == TrKeys.waiter ||
                              LocalStorage.getUser()?.role == TrKeys.seller
                          ? shippingOptions
                          : listDine)
                      .map((e) => Expanded(
                            child: InkWell(
                              onTap: () {
                                notifier.setSelectedOrderType(e);
                                if (state.orderType.toLowerCase() !=
                                    e.toString().toLowerCase()) {
                                  ref
                                      .read(rightSideProvider.notifier)
                                      .fetchCarts(
                                          checkYourNetwork: () {
                                            AppHelpers.showSnackBar(
                                              context,
                                              AppHelpers.getTranslation(TrKeys
                                                  .checkYourNetworkConnection),
                                            );
                                          },
                                          isNotLoading: true);
                                }
                              },
                              child: AnimationButtonEffect(
                                child: Container(
                                  margin: EdgeInsets.symmetric(horizontal: 4.r),
                                  decoration: BoxDecoration(
                                    color: state.orderType.toLowerCase() ==
                                            e.toString().toLowerCase()
                                        ? AppStyle.primary
                                        : AppStyle.editProfileCircle,
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 8.r),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: AppStyle.transparent,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: AppStyle.black),
                                          ),
                                          padding: EdgeInsets.all(6.r),
                                          child: e == TrKeys.delivery
                                              ? Icon(
                                                  FlutterRemix.takeaway_fill,
                                                  size: 18.sp,
                                                )
                                              : e == TrKeys.pickup
                                                  ? SvgPicture.asset(
                                                      "assets/svg/pickup.svg")
                                                  : e == TrKeys.dine
                                                      ? SvgPicture.asset(
                                                          "assets/svg/dine.svg")
                                                      : (e == TrKeys.grab ||
                                                              e == TrKeys.food)
                                                          ? Icon(
                                                              FlutterRemix
                                                                  .e_bike_2_fill,
                                                              size: 18.sp)
                                                          : const SizedBox
                                                              .shrink(),
                                        ),
                                        4.verticalSpace,
                                        Text(
                                          AppHelpers.getTranslation(e),
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w600),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )),
                ],
              ),
              12.verticalSpace,
              const Divider(),
              24.verticalSpace,
              _priceInformation(
                state: state,
                bag: bag,
                context: context,
                subtotal: subtotal,
                totalDiscount: totalDiscount,
              ),
              20.verticalSpace,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 186.w,
                    child: LoginButton(
                        title: AppHelpers.getTranslation(TrKeys.placeOrder),
                        onPressed: () {
                          if (AppHelpers.isNumberRequiredToOrder() &&
                              state.selectedUser?.phone == null &&
                              state.selectedUser != null) {
                            if (!(formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                          }
                          notifier.placeOrder(
                            checkYourNetwork: () {
                              AppHelpers.showSnackBar(
                                context,
                                AppHelpers.getTranslation(
                                    TrKeys.checkYourNetworkConnection),
                              );
                            },
                            openSelectDeliveriesDrawer: () {
                              // 1. Create a copy with the correct final values.
                              final updatedResponse =
                                  state.paginateResponse?.copyWith(
                                totalPrice: finalTotal,
                                totalDiscount: totalDiscount,
                              );

                              // 2. THIS IS THE NEW, CRITICAL STEP:
                              // Update the state that the payment screen actually uses.
                              notifier.updatePaginateResponse(updatedResponse);

                              // 3. This line now correctly shows the payment screen
                              //    using the data we just updated.
                              ref
                                  .read(mainProvider.notifier)
                                  .setPriceDate(updatedResponse);

                              context.maybePop();
                            },
                          );
                        }),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppHelpers.getTranslation(TrKeys.totalPrice),
                        style: GoogleFonts.inter(
                          color: AppStyle.black,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        AppHelpers.numberFormat(
                          finalTotal,
                          symbol: bag.selectedCurrency?.symbol,
                        ),
                        style: GoogleFonts.inter(
                          color: AppStyle.black,
                          fontSize: 30.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priceInformation({
    required RightSideState state,
    required BagData bag,
    required BuildContext context,
    required num subtotal,
    required num totalDiscount,
  }) {
    return Column(
      children: [
        _priceItem(
          title: TrKeys.subtotal,
          price: subtotal,
          symbol: bag.selectedCurrency?.symbol,
        ),
        _priceItem(
          title: TrKeys.tax,
          price: state.paginateResponse?.totalTax,
          symbol: bag.selectedCurrency?.symbol,
        ),
        _priceItem(
          title: TrKeys.serviceFee,
          price: state.paginateResponse?.serviceFee,
          symbol: bag.selectedCurrency?.symbol,
        ),
        _priceItem(
          title: TrKeys.deliveryFee,
          price: state.paginateResponse?.deliveryFee,
          symbol: bag.selectedCurrency?.symbol,
        ),
        _priceItem(
          title: TrKeys.discount,
          price: totalDiscount,
          symbol: bag.selectedCurrency?.symbol,
          isDiscount: true,
        ),
        _priceItem(
          title: TrKeys.promoCode,
          price: state.paginateResponse?.couponPrice,
          symbol: bag.selectedCurrency?.symbol,
          isDiscount: true,
        ),
        const Divider(),
      ],
    );
  }

  _priceItem({
    required String title,
    required num? price,
    required String? symbol,
    bool isDiscount = false,
  }) {
    return (price ?? 0) != 0
        ? Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppHelpers.getTranslation(title),
                    style: GoogleFonts.inter(
                      color: isDiscount ? AppStyle.red : AppStyle.black,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    (isDiscount ? "-" : '') +
                        AppHelpers.numberFormat(price, symbol: symbol),
                    style: GoogleFonts.inter(
                      color: isDiscount ? AppStyle.red : AppStyle.black,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              12.verticalSpace,
            ],
          )
        : const SizedBox.shrink();
  }
}
