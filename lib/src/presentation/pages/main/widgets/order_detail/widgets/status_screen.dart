import 'package:admin_desktop/src/core/utils/utils.dart';
import 'package:admin_desktop/src/models/data/shop_data.dart';
import 'package:admin_desktop/src/presentation/components/common_image.dart';
import 'package:admin_desktop/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'order_status.dart';

class StatusScreen extends StatelessWidget {
  final String orderDataStatus;
  final ShopData? shop;

  const StatusScreen(
      {super.key, required this.orderDataStatus, required this.shop});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppStyle.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppStyle.border),
      ),
      padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 16.w),
      child: Row(
        children: [
          Container(
            width: 50.r,
            height: 50.r,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.r),
                color: AppStyle.editProfileCircle),
            padding: EdgeInsets.all(8.r),
            child: CommonImage(
              imageUrl: shop?.logoImg,
              radius: 25,
            ),
          ),
          16.horizontalSpace,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shop?.translation?.title ?? "",
                style: GoogleFonts.inter(fontSize: 18.r, color: AppStyle.black),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width / 2 - 100.w,
                child: Text(
                  shop?.translation?.description ?? "",
                  style:
                      GoogleFonts.inter(fontSize: 14.r, color: AppStyle.black),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            ],
          ),
          const Spacer(),
          Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              return OrderStatusScreen(
                status: AppHelpers.getOrderStatus(orderDataStatus),
              );
            },
          )
        ],
      ),
    );
  }
}
