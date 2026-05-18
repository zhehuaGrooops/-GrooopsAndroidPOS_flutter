import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:admin_desktop/src/core/utils/app_helpers.dart';
import 'package:admin_desktop/src/core/utils/utils.dart';
import 'package:admin_desktop/src/models/data/order_data.dart';
import 'package:admin_desktop/src/presentation/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class ProductTable extends StatelessWidget {
  final OrderData? orderData;
  final Function(int?, String) onEdit;

  const ProductTable(
      {super.key, required this.orderData, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: {
        0: FixedColumnWidth(66.w),
        1: FixedColumnWidth(168.w),
        2: FixedColumnWidth(112.w),
        3: FixedColumnWidth(80.w),
        4: FixedColumnWidth(80.w),
        5: FixedColumnWidth(100.w),
      },
      border: TableBorder.all(color: AppStyle.transparent),
      children: [
        TableRow(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppHelpers.getTranslation(TrKeys.id),
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    color: AppStyle.black,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                )
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppHelpers.getTranslation(TrKeys.productName),
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    color: AppStyle.black,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                )
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppHelpers.getTranslation(TrKeys.status),
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    color: AppStyle.black,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                )
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppHelpers.getTranslation(TrKeys.kitchen),
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    color: AppStyle.black,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                )
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppHelpers.getTranslation(TrKeys.quantity),
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    color: AppStyle.black,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                )
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppHelpers.getTranslation(TrKeys.totalPrice),
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    color: AppStyle.black,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                )
              ],
            ),
          ],
        ),
        for (int i = 0; i < (orderData?.details?.length ?? 0); i++)
          TableRow(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    Text(
                      "#${orderData?.details?[i].id ?? 0}",
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        color: AppStyle.icon,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    Text(
                      (orderData?.details?[i].stock?.translation?.title ?? ""),
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        color: AppStyle.icon,
                        letterSpacing: -0.3,
                      ),
                    )
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    GestureDetector(
                      onTap: () {},
                      child: Row(
                        children: [
                          Text(
                            AppHelpers.getTranslation(
                                orderData?.details?[i].status ?? ""),
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              color: AppStyle.icon,
                              letterSpacing: -0.3,
                            ),
                          ),
                          8.horizontalSpace,
                          if (orderData?.details?[i].status != TrKeys.canceled)
                            GestureDetector(
                              child: const Icon(
                                FlutterRemix.edit_2_line,
                                color: AppStyle.icon,
                              ),
                              onTap: () {
                                onEdit.call(orderData?.details?[i].id,
                                    orderData?.details?[i].status ?? "");
                              },
                            )
                        ],
                      ),
                    )
                  ],
                ),
              ),
              Padding(
                padding: REdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    Text(
                      orderData?.details?[i].kitchen?.translation?.title ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        color: AppStyle.icon,
                        letterSpacing: -0.3,
                      ),
                    )
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    Text(
                      "${(orderData?.details?[i].quantity ?? 1) * (orderData?.details?[i].stock?.product?.interval ?? 1)} ${orderData?.details?[i].stock?.product?.unit?.translation?.title ?? 0}",
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        color: AppStyle.icon,
                        letterSpacing: -0.3,
                      ),
                    )
                  ],
                ),
              ),
              Padding(
                padding: REdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    Text(
                      AppHelpers.numberFormat(
                        orderData?.details?[i].totalPrice ?? 0,
                        symbol: orderData?.currency?.symbol,
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        color: AppStyle.icon,
                        letterSpacing: -0.3,
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        for (int i = 0; i < (orderData?.details?.length ?? 0); i++)
          for (int j = 0; j < (orderData?.details?[i].addons?.length ?? 0); j++)
            TableRow(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      Text(
                        "#${orderData?.details?[i].addons?[j].id ?? 0}",
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          color: AppStyle.icon,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      Text(
                        (orderData?.details?[i].addons?[j].stocks?.product
                                ?.translation?.title ??
                            ""),
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          color: AppStyle.icon,
                          letterSpacing: -0.3,
                        ),
                      )
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      Text(
                        "",
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          color: AppStyle.icon,
                          letterSpacing: -0.3,
                        ),
                      )
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      Text(
                        "",
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          color: AppStyle.icon,
                          letterSpacing: -0.3,
                        ),
                      )
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      Text(
                        (orderData?.details?[i].addons?[j].quantity ?? 0)
                            .toString(),
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          color: AppStyle.icon,
                          letterSpacing: -0.3,
                        ),
                      )
                    ],
                  ),
                ),
                Padding(
                  padding: REdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      Text(
                        AppHelpers.numberFormat(
                          orderData?.details?[i].addons?[j].price ?? 0,
                          symbol: orderData?.currency?.symbol,
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          color: AppStyle.icon,
                          letterSpacing: -0.3,
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
      ],
    );
  }
}
