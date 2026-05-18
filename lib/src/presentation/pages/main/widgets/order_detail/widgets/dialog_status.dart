import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../../core/constants/constants.dart';
import '../../../../../../core/utils/utils.dart';
import '../../../../../components/login_button.dart';
import '../../../../../theme/app_style.dart';
import '../order_riverpod/order_details_provider.dart';

class DialogStatus extends StatelessWidget {
  final OrderStatus orderStatus;
  const DialogStatus({super.key, required this.orderStatus});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250.w,
      decoration: BoxDecoration(
          color: AppStyle.white, borderRadius: BorderRadius.circular(16.r)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "${AppHelpers.getTranslation(TrKeys.areYouSureChange)} ${AppHelpers.getOrderStatusText(orderStatus)}",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 18.sp),
          ),
          24.verticalSpace,
          Row(
            children: [
              Expanded(
                child: LoginButton(
                    title: AppHelpers.getTranslation(TrKeys.cancel),
                    onPressed: () {
                      context.maybePop();
                    }),
              ),
              24.horizontalSpace,
              Expanded(
                child: Consumer(
                  builder:
                      (BuildContext context, WidgetRef ref, Widget? child) {
                    return LoginButton(
                        isLoading: ref.watch(orderDetailsProvider).isUpdating,
                        title: AppHelpers.getTranslation(TrKeys.apply),
                        onPressed: () {
                          ref
                              .read(orderDetailsProvider.notifier)
                              .updateOrderStatus(
                                  status: orderStatus,
                                  success: () {
                                    context.maybePop();
                                  });
                        });
                  },
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}
