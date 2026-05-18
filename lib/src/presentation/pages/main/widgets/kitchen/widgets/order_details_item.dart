import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:admin_desktop/src/core/utils/utils.dart';
import 'package:admin_desktop/src/models/data/addons_data.dart';
import 'package:admin_desktop/src/models/data/order_data.dart';
import 'package:admin_desktop/src/models/models.dart';
import 'package:admin_desktop/src/presentation/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class OrderDetailsItem extends StatelessWidget {
  final OrderDetail? orderDetail;
  final Function(int?, String) onEdit;

  const OrderDetailsItem(
      {super.key, required this.orderDetail, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.r),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${orderDetail?.stock?.product?.translation?.title ?? ""} x ${orderDetail?.quantity ?? ""} ${orderDetail?.stock?.product?.unit?.translation?.title ?? ""}",
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 16.sp,
                      color: AppStyle.black),
                ),
                2.verticalSpace,
                Wrap(
                  children: [
                    for (Extras e in (orderDetail?.stock?.extras ?? []))
                      Text(
                        "${e.group?.translation?.title ?? ""}: ${e.value ?? ""}, ",
                        style: GoogleFonts.inter(
                          fontSize: 15.sp,
                          color: AppStyle.unselectedTab,
                        ),
                      ),
                  ],
                ),
                6.verticalSpace,
                for (Addons e in (orderDetail?.addons ?? []))
                  Text(
                    "${e.stocks?.product?.translation?.title ?? ""} ( x ${(e.quantity ?? 1)} ${(e.stocks?.product?.unit?.translation?.title ?? 1)} )",
                    style: GoogleFonts.inter(
                      fontSize: 15.sp,
                      color: AppStyle.unselectedTab,
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              if (orderDetail?.status != TrKeys.canceled &&
                  orderDetail?.status != TrKeys.ready) {
                onEdit.call(orderDetail?.id, orderDetail?.status ?? "");
              }
            },
            child: Container(
              padding: REdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: AppHelpers.getStatusColor(orderDetail?.status),
                  borderRadius: BorderRadius.circular(16.r)),
              child: Row(
                children: [
                  Text(
                    AppHelpers.getTranslation(orderDetail?.status ?? ''),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 16.sp,
                      color: AppStyle.white,
                    ),
                  ),
                  if (orderDetail?.status != TrKeys.canceled &&
                      orderDetail?.status != TrKeys.ready)
                    Padding(
                      padding: REdgeInsets.only(left: 6),
                      child: Icon(
                        FlutterRemix.pencil_fill,
                        color: AppStyle.white,
                        size: 21.r,
                      ),
                    )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
