import 'package:admin_desktop/generated/assets.dart';
import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:admin_desktop/src/core/utils/app_helpers.dart';
import 'package:admin_desktop/src/core/utils/local_storage.dart';
import 'package:admin_desktop/src/presentation/components/buttons/animation_button_effect.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/order_detail/widgets/dialog_status.dart';
import 'package:admin_desktop/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'order_status_item.dart';

class OrderStatusScreen extends StatelessWidget {
  final OrderStatus status;

  const OrderStatusScreen({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: AppStyle.editProfileCircle,
          borderRadius: BorderRadius.all(Radius.circular(100.r))),
      padding: EdgeInsets.all(14.r),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              16.horizontalSpace,
              Text(
                AppHelpers.getTranslation(
                    AppHelpers.getOrderStatusText(status)),
                style: GoogleFonts.inter(
                  color: AppStyle.black,
                ),
              ),
            ],
          ),
          64.horizontalSpace,
          status == OrderStatus.canceled
              ? Row(
                  children: [
                    OrderStatusItem(
                      icon: Icon(
                        Icons.done_all,
                        size: 24.r,
                      ),
                      bgColor: AppStyle.red,
                      isActive: true,
                      isProgress: false,
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      height: 6.h,
                      width: 12.w,
                      decoration: const BoxDecoration(
                        color: AppStyle.red,
                      ),
                    ),
                    OrderStatusItem(
                      icon: Icon(
                        Icons.restaurant_rounded,
                        size: 24.r,
                        color: AppStyle.black,
                      ),
                      bgColor: AppStyle.red,
                      isActive: true,
                      isProgress: false,
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      height: 6.r,
                      width: 12.r,
                      decoration: const BoxDecoration(
                        color: AppStyle.red,
                      ),
                    ),
                    OrderStatusItem(
                      icon: SvgPicture.asset(
                        Assets.svgDelivery2,
                        width: 26.r,
                      ),
                      bgColor: AppStyle.red,
                      isActive: true,
                      isProgress: false,
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      height: 6.r,
                      width: 12.r,
                      decoration: const BoxDecoration(
                        color: AppStyle.red,
                      ),
                    ),
                    OrderStatusItem(
                      icon: Icon(
                        Icons.flag,
                        size: 24.r,
                      ),
                      bgColor: AppStyle.red,
                      isActive: true,
                      isProgress: false,
                    ),
                  ],
                )
              : status == OrderStatus.delivered
                  ? Row(
                      children: [
                        OrderStatusItem(
                          icon: Icon(
                            Icons.done_all,
                            size: 24.r,
                          ),
                          bgColor: AppStyle.primary,
                          isActive: true,
                          isProgress: false,
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          height: 6.h,
                          width: 12.w,
                          decoration: const BoxDecoration(
                            color: AppStyle.primary,
                          ),
                        ),
                        OrderStatusItem(
                          icon: Icon(
                            Icons.restaurant_rounded,
                            size: 24.r,
                            color: AppStyle.black,
                          ),
                          bgColor: AppStyle.primary,
                          isActive: true,
                          isProgress: false,
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          height: 6.r,
                          width: 12.r,
                          decoration: const BoxDecoration(
                            color: AppStyle.primary,
                          ),
                        ),
                        OrderStatusItem(
                          icon: SvgPicture.asset(
                            Assets.svgDelivery2,
                            width: 26.r,
                          ),
                          bgColor: AppStyle.primary,
                          isActive: true,
                          isProgress: false,
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          height: 6.r,
                          width: 12.r,
                          decoration: const BoxDecoration(
                            color: AppStyle.primary,
                          ),
                        ),
                        OrderStatusItem(
                          icon: Icon(
                            Icons.flag,
                            size: 24.r,
                          ),
                          bgColor: AppStyle.primary,
                          isActive: true,
                          isProgress: false,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        OrderStatusItem(
                          icon: Icon(Icons.done_all, size: 24.r),
                          isActive: status != OrderStatus.newOrder,
                          isProgress: status == OrderStatus.newOrder,
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          height: 6.r,
                          width: 12.r,
                          decoration: BoxDecoration(
                            color: status != OrderStatus.newOrder
                                ? AppStyle.primary
                                : AppStyle.white,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            if (LocalStorage.getUser()?.role != TrKeys.waiter) {
                              AppHelpers.showAlertDialog(
                                  context: context,
                                  child: const DialogStatus(
                                      orderStatus: OrderStatus.ready));
                            }
                          },
                          child: AnimationButtonEffect(
                            child: OrderStatusItem(
                              icon: Icon(
                                Icons.restaurant_rounded,
                                size: 24.r,
                                color: AppStyle.black,
                              ),
                              isActive: status == OrderStatus.ready ||
                                  status == OrderStatus.onAWay,
                              isProgress: status == OrderStatus.accepted,
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          height: 6.r,
                          width: 12.r,
                          decoration: BoxDecoration(
                            color: status == OrderStatus.ready ||
                                    status == OrderStatus.onAWay
                                ? AppStyle.primary
                                : AppStyle.white,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            if (LocalStorage.getUser()?.role != TrKeys.waiter) {
                              AppHelpers.showAlertDialog(
                                  context: context,
                                  child: const DialogStatus(
                                      orderStatus: OrderStatus.onAWay));
                            }
                          },
                          child: AnimationButtonEffect(
                            child: OrderStatusItem(
                              icon: SvgPicture.asset(
                                status == OrderStatus.onAWay
                                    ? Assets.svgDelivery2
                                    : Assets.svgDelivery,
                                width: 26.r,
                              ),
                              isActive: status == OrderStatus.onAWay,
                              isProgress: status == OrderStatus.ready ||
                                  status == OrderStatus.delivered,
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          height: 6.r,
                          width: 12.r,
                          decoration: BoxDecoration(
                            color: status == OrderStatus.onAWay
                                ? AppStyle.primary
                                : AppStyle.white,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            if (LocalStorage.getUser()?.role != TrKeys.waiter) {
                              AppHelpers.showAlertDialog(
                                  context: context,
                                  child: const DialogStatus(
                                      orderStatus: OrderStatus.delivered));
                            }
                          },
                          child: AnimationButtonEffect(
                            child: OrderStatusItem(
                              icon: Icon(
                                Icons.flag,
                                size: 24.r,
                              ),
                              isActive: false,
                              isProgress: false,
                            ),
                          ),
                        ),
                      ],
                    )
        ],
      ),
    );
  }
}
