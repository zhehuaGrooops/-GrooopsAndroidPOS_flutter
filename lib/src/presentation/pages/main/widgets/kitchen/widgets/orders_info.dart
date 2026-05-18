import 'package:admin_desktop/generated/assets.dart';
import 'package:admin_desktop/src/core/utils/time_service.dart';
import 'package:admin_desktop/src/models/data/order_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../core/constants/constants.dart';
import '../../../../../../core/utils/app_helpers.dart';
import '../../../../../theme/app_style.dart';

class OrdersInfo extends StatelessWidget {
  final bool active;
  final OrderData orderData;

  const OrdersInfo({super.key, required this.active, required this.orderData});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: REdgeInsets.only(bottom: 12),
      width: 228.r,
      decoration: BoxDecoration(
        color: AppStyle.white,
        borderRadius: BorderRadiusDirectional.circular(10),
        boxShadow: [
          BoxShadow(
              offset: const Offset(0, 5),
              blurRadius: 8.r,
              color: active ? AppStyle.shadowSecond : AppStyle.transparent)
        ],
        border:
            Border.all(color: active ? AppStyle.primary : AppStyle.transparent),
      ),
      child: Padding(
        padding: REdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "#${AppHelpers.getTranslation(TrKeys.id)}${orderData.id ?? ''}",
              style: GoogleFonts.inter(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: AppStyle.black,
              ),
            ),
            4.verticalSpace,
            Divider(
              color: AppStyle.icon.withOpacity(0.6),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppHelpers.getTranslation(TrKeys.orderTime),
                  style: GoogleFonts.inter(
                      fontSize: 14.sp, fontWeight: FontWeight.w500),
                ),
                Text(
                  TimeService.dateFormatMDHm(
                      DateTime.parse(orderData.createdAt ?? "").toLocal()),
                  style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: AppStyle.icon),
                ),
              ],
            ),
            Divider(
              color: AppStyle.icon.withOpacity(0.6),
            ),
            4.verticalSpace,
            const Spacer(),
            Row(
              children: [
                Container(
                  height: 30.r,
                  width: 30.r,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppStyle.black)),
                  child: Center(
                      child: orderData.deliveryType == TrKeys.dine
                          ? SvgPicture.asset(Assets.svgDine)
                          : Icon(
                              orderData.deliveryType == TrKeys.pickup
                                  ? FlutterRemix.walk_line
                                  : FlutterRemix.e_bike_2_fill,
                              size: 18,
                            )),
                ),
                8.horizontalSpace,
                orderData.deliveryType == TrKeys.pickup
                    ? Text(
                        AppHelpers.getTranslation(TrKeys.takeAway),
                        style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppStyle.black),
                      )
                    : orderData.deliveryType == TrKeys.dine
                        ? Text(
                            AppHelpers.getTranslation(TrKeys.dine),
                            style: GoogleFonts.inter(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: AppStyle.black),
                          )
                        : Text(
                            AppHelpers.getTranslation(TrKeys.delivery),
                            style: GoogleFonts.inter(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: AppStyle.black),
                          )
              ],
            ),
            const Spacer(flex: 2),
            Container(
              padding: REdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppHelpers.getStatusColor(orderData.status),
                borderRadius: BorderRadius.circular(100.r),
              ),
              child: Text(
                AppHelpers.getTranslation(orderData.status ?? ''),
                style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppStyle.white),
              ),
            )
          ],
        ),
      ),
    );
  }
}
