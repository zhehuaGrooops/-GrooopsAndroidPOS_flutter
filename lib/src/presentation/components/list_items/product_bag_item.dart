import 'package:admin_desktop/src/core/constants/tr_keys.dart';
import 'package:admin_desktop/src/models/data/addons_data.dart';
import 'package:admin_desktop/src/models/data/product_data.dart';
import 'package:admin_desktop/src/presentation/components/buttons/animation_button_effect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/utils/utils.dart';
import '../../theme/theme.dart';

class CartOrderItem extends StatelessWidget {
  final ProductData? cart;
  final String? symbol;
  final String? discountSelection;
  final ValueChanged<String?>? onDiscountChanged;
  final DiscountSetting? externalDiscountSetting;
  final VoidCallback add;
  final VoidCallback remove;
  final VoidCallback delete;
  final bool isActive;
  final bool isOwn;

  const CartOrderItem({
    super.key,
    required this.add,
    required this.remove,
    required this.cart,
    required this.delete,
    this.isActive = true,
    this.isOwn = true,
    required this.symbol,
    this.discountSelection,
    this.onDiscountChanged,
    this.externalDiscountSetting,
  });

  @override
  Widget build(BuildContext context) {
    // compute addons total and base price
    num addonsTotal = 0;
    for (Addons e in (cart?.addons ?? [])) {
      addonsTotal += (e.price ?? 0);
    }

    final num productPrice = (cart?.stock?.price ?? 0) * (cart?.quantity ?? 1);
    final num basePrice = productPrice + addonsTotal;

    // prefer externalDiscountSetting (passed from parent) then category.discountSetting
    final discountSetting = externalDiscountSetting ??
        cart?.category?.discountSetting ??
        cart?.stock?.product?.category?.discountSetting;

    // apply discount when user selected 'with'. If discountSetting is missing
    // we still mark the discount as applied for UI feedback, but only compute
    // the reduced finalPrice when discountSetting is available. Ensure final
    // price never goes negative — clamp to 0.
    num finalPrice = basePrice;
    bool appliedDiscount = false;
    final bool userChoseWith = (discountSelection ?? 'default') == 'with';
    if (userChoseWith) {
      appliedDiscount = true;
      if (discountSetting != null) {
        if (discountSetting.method == 'percent') {
          finalPrice -= productPrice * ((discountSetting.value ?? 0) / 100);
        } else if (discountSetting.method == 'amount') {
          finalPrice -= (discountSetting.value ?? 0);
        }
      }
    }

    // Prevent negative final price (discount can't exceed item price)
    if (finalPrice < 0) finalPrice = 0;

    // compute discount amount shown in badge (positive number)
    num discountAmount = (basePrice - finalPrice);
    if (discountAmount < 0) discountAmount = 0;

    // price debug: computed basePrice/finalPrice kept for reference during development

    return Slidable(
      endActionPane: ActionPane(
        extentRatio: 0.12,
        motion: const ScrollMotion(),
        children: [
          Expanded(
            child: Builder(
              builder: (context) {
                return GestureDetector(
                  onTap: () {
                    Slidable.of(context)?.close();
                    delete.call();
                  },
                  child: Container(
                    width: 50.r,
                    height: 72.r,
                    decoration: BoxDecoration(
                      color: AppStyle.red,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16.r),
                        bottomLeft: Radius.circular(16.r),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      FlutterRemix.close_fill,
                      color: AppStyle.white,
                      size: 24.r,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          if (isActive && cart?.bonus == null)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppStyle.white,
                borderRadius: BorderRadius.all(
                  Radius.circular(10.r),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.r),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      cart?.stock?.product?.translation
                                              ?.title ??
                                          '',
                                      style: GoogleFonts.inter(
                                        fontSize: 14.sp,
                                        color: AppStyle.black,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120.r,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8.r, vertical: 6.r),
                                      decoration: BoxDecoration(
                                        color: AppStyle.white,
                                        border: Border.all(
                                            color: AppStyle.border, width: 1),
                                        borderRadius:
                                            BorderRadius.circular(6.r),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          isExpanded: true,
                                          value: discountSelection ?? 'default',
                                          dropdownColor: AppStyle.white,
                                          iconEnabledColor: AppStyle.black,
                                          style: GoogleFonts.inter(
                                              fontSize: 13.sp,
                                              color: AppStyle.black),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'default',
                                              child: Text('Default'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'with',
                                              child: Text('With Discount'),
                                            ),
                                          ],
                                          onChanged: (v) {
                                            onDiscountChanged?.call(v);
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              8.verticalSpace,
                              for (Addons e in (cart?.addons ?? []))
                                Text(
                                  "${e.product?.translation?.title ?? ""} ( ${intl.NumberFormat.currency(
                                    symbol: symbol ??
                                        LocalStorage.getSelectedCurrency()
                                            .symbol,
                                  ).format((e.price ?? 0) / (e.quantity ?? 1))} x ${(e.quantity ?? 1)} )",
                                  style: GoogleFonts.inter(
                                    fontSize: 12.sp,
                                    color: AppStyle.unselectedTab,
                                  ),
                                ),
                              16.verticalSpace,
                            ],
                          ),
                        ),
                      ),
                      4.horizontalSpace,
                      (cart?.stock?.bonus != null || (cart?.bonus ?? false))
                          ? Positioned(
                              bottom: 4.r,
                              right: 4.r,
                              child: Container(
                                width: 22.w,
                                height: 22.h,
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppStyle.blue),
                                child: Icon(
                                  FlutterRemix.gift_2_fill,
                                  size: 14.r,
                                  color: AppStyle.white,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            vertical: 10.h, horizontal: 16.w),
                        decoration: BoxDecoration(
                            color: AppStyle.primary,
                            borderRadius: BorderRadius.only(
                                topRight: Radius.circular(10.r),
                                bottomRight: Radius.circular(10.r))),
                        child: Text(
                          "${(cart?.quantity ?? 1).toString()}x",
                          style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              color: AppStyle.black,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      24.horizontalSpace,
                      GestureDetector(
                        onTap: remove,
                        child: AnimationButtonEffect(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppStyle.removeButtonColor,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(10.r),
                                bottomLeft: Radius.circular(10.r),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: 8.h, horizontal: 25.w),
                              child: const Icon(
                                Icons.remove,
                                color: AppStyle.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                      4.horizontalSpace,
                      GestureDetector(
                        onTap: add,
                        child: AnimationButtonEffect(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppStyle.addButtonColor,
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(10.r),
                                bottomRight: Radius.circular(10.r),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: 8.h, horizontal: 25.w),
                              child: const Icon(
                                Icons.add,
                                color: AppStyle.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      !(cart?.stock?.bonus != null || (cart?.bonus ?? false))
                          ? Column(
                              children: [
                                Text(
                                  AppHelpers.numberFormat(
                                    basePrice,
                                    symbol: symbol,
                                  ),
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: appliedDiscount ? 12.sp : 16.sp,
                                    color: AppStyle.black,
                                    decoration: appliedDiscount
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                ),
                                appliedDiscount
                                    ? Container(
                                        margin: EdgeInsets.only(top: 8.r),
                                        decoration: BoxDecoration(
                                            color: AppStyle.red,
                                            borderRadius:
                                                BorderRadius.circular(30.r)),
                                        padding: EdgeInsets.all(4.r),
                                        child: Row(
                                          children: [
                                            SvgPicture.asset(
                                                "assets/svg/discount.svg"),
                                            4.horizontalSpace,
                                            Text(
                                              AppHelpers.numberFormat(
                                                finalPrice,
                                                symbol: symbol,
                                              ),
                                              style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14.sp,
                                                  color: AppStyle.white),
                                            )
                                          ],
                                        ),
                                      )
                                    : const SizedBox.shrink()
                              ],
                            )
                          : const SizedBox.shrink(),
                      16.horizontalSpace,
                    ],
                  ),
                ],
              ),
            )
          else
            Container(
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.all(16.r),
              width: double.infinity,
              decoration: BoxDecoration(
                  color: AppStyle.white,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: AppStyle.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  RichText(
                      text: TextSpan(
                          text: cart?.stock?.product?.translation?.title,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: AppStyle.black,
                          ),
                          children: [
                        if (cart?.stock?.extras?.isNotEmpty ?? false)
                          TextSpan(
                            text:
                                " (${cart?.stock?.extras?.first.value ?? ""})",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppStyle.hint,
                            ),
                          )
                      ])),
                  8.verticalSpace,
                  for (Addons e in (cart?.addons ?? []))
                    Text(
                      "${e.product?.translation?.title ?? ""} ( ${AppHelpers.numberFormat(
                        (e.price ?? 0) / (e.quantity ?? 1),
                        symbol: symbol,
                      )} x ${(e.quantity ?? 1)} )",
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        color: AppStyle.black,
                      ),
                    ),
                  8.verticalSpace,
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${AppHelpers.numberFormat(
                            (basePrice) / (cart?.quantity ?? 1),
                            symbol: symbol,
                          )} X ${cart?.quantity ?? 1}",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppStyle.black,
                          ),
                        ),
                      ),
                      Container(
                        width: 32.w,
                        height: 32.h,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: AppStyle.blue),
                        child: Icon(
                          FlutterRemix.gift_2_fill,
                          size: 20.r,
                          color: AppStyle.white,
                        ),
                      ),
                      4.horizontalSpace,
                      Text(AppHelpers.getTranslation(TrKeys.bonus)),
                      4.horizontalSpace,
                    ],
                  ),
                ],
              ),
            ),
          isActive ? const Divider() : const SizedBox.shrink(),
        ],
      ),
    );
  }
}
