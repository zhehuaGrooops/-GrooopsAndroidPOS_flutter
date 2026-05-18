import 'package:flutter/material.dart';
import 'package:admin_desktop/generated/assets.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../../core/constants/constants.dart';
import '../../../../../../core/utils/app_helpers.dart';
import '../../../../../../models/data/table_bookings_data.dart';
import '../../../../../components/common_image.dart';
import '../../../../../theme/app_style.dart';

class TableOrder extends StatelessWidget {
  final TableBookingData? tableBookingData;
  final bool active;

  const TableOrder(
      {super.key, required this.active, required this.tableBookingData});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: REdgeInsets.only(bottom: 12),
      width: 228.w,
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
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CommonImage(
                    height: 40,
                    width: 40,
                    radius: 100,
                    imageUrl: tableBookingData?.user?.img),
                10.horizontalSpace,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tableBookingData?.user?.firstname ?? ""} ${tableBookingData?.user?.lastname ?? ""}.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500,
                          color: AppStyle.black),
                    ),
                    2.verticalSpace,
                    Text(
                      '#${AppHelpers.getTranslation(TrKeys.id)}${tableBookingData?.id}',
                      style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: AppStyle.icon),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(FlutterRemix.more_2_fill, size: 22.r)
              ],
            ),
            Expanded(
              child: Divider(color: AppStyle.icon.withOpacity(0.6)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppHelpers.getTranslation(TrKeys.startTime),
                  style: GoogleFonts.inter(
                      fontSize: 14.sp, fontWeight: FontWeight.w500),
                ),
                Text(
                  DateFormat("MMM d,h:mm a")
                      .format(tableBookingData?.startDate ?? DateTime.now()),
                  style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: AppStyle.icon),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppHelpers.getTranslation(TrKeys.endTime),
                  style: GoogleFonts.inter(
                      fontSize: 14.sp, fontWeight: FontWeight.w500),
                ),
                Text(
                  DateFormat("MMM d,h:mm a")
                      .format(tableBookingData?.endDate ?? DateTime.now()),
                  style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: AppStyle.icon),
                ),
              ],
            ),
            Expanded(
              child: Divider(color: AppStyle.icon.withOpacity(0.6)),
            ),
            4.verticalSpace,
            Row(
              children: [
                Container(
                  height: 30.r,
                  width: 30.r,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppStyle.black)),
                  child: Center(
                      child: SvgPicture.asset(
                    Assets.svgDine,
                    height: 18.r,
                    width: 18.r,
                  )),
                ),
                8.horizontalSpace,
                Text(
                  tableBookingData?.table?.name ?? "",
                  style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: AppStyle.icon),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                  color: tableBookingData?.status == TrKeys.newKey
                      ? AppStyle.blue
                      : tableBookingData?.status == TrKeys.accepted
                          ? AppStyle.deepPurple
                          : tableBookingData?.status == TrKeys.canceled
                              ? AppStyle.red
                              : AppStyle.revenueColor,
                  borderRadius: BorderRadiusDirectional.circular(100)),
              child: Text(
                AppHelpers.getTranslation(tableBookingData?.status ?? ""),
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
