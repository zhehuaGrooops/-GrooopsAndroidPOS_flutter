import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:admin_desktop/src/core/utils/utils.dart';
import 'package:admin_desktop/src/models/data/order_data.dart';
import 'package:admin_desktop/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_bar_item.dart';

class DetailAppBar extends StatelessWidget {
  final OrderData? orderData;

  const DetailAppBar({super.key, required this.orderData});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppStyle.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppStyle.border),
      ),
      padding: EdgeInsets.all(24.r),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AppbarItem(
              title: AppHelpers.getTranslation(TrKeys.deliveryDate),
              icon: FlutterRemix.calendar_line,
              desc: orderData?.deliveryDate ?? ""),
          AppbarItem(
              title: AppHelpers.getTranslation(TrKeys.totalPrice),
              icon: FlutterRemix.bank_card_line,
              desc: AppHelpers.numberFormat(
                orderData?.totalPrice ?? 0,
              )),
          AppbarItem(
              title: AppHelpers.getTranslation(TrKeys.messages),
              icon: FlutterRemix.message_2_line,
              desc: orderData?.deliveryDate ?? ""),
          AppbarItem(
              title: AppHelpers.getTranslation(TrKeys.products),
              icon: FlutterRemix.shopping_cart_line,
              desc: "${orderData?.details?.length ?? 0}"),
        ],
      ),
    );
  }
}
