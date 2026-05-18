import 'package:admin_desktop/src/core/utils/time_service.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/kitchen/riverpod/kitchen_provider.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/kitchen/widgets/order_details_item.dart';
import 'package:admin_desktop/src/presentation/theme/app_style.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/constants/constants.dart';
import '../../../../../core/utils/app_helpers.dart';
import '../../../../components/components.dart';

class OrderInfo extends ConsumerStatefulWidget {
  const OrderInfo({super.key});

  @override
  ConsumerState<OrderInfo> createState() => _OrderInfoState();
}

class _OrderInfoState extends ConsumerState<OrderInfo> {
  @override
  Widget build(
    BuildContext context,
  ) {
    final state = ref.watch(kitchenProvider);
    final event = ref.read(kitchenProvider.notifier);
    return Container(
      margin: EdgeInsets.only(right: 16.r, top: 16.r, bottom: 16.r),
      padding: REdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppStyle.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: state.selectOrder != null
          ? SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      6.verticalSpace,
                      Text(
                        AppHelpers.getTranslation(TrKeys.order),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 18.sp,
                        ),
                      ),
                      10.verticalSpace,
                      Row(
                        children: [
                          Text(
                            "#${AppHelpers.getTranslation(TrKeys.id)}${state.selectOrder?.id}",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500,
                              fontSize: 16.sp,
                              color: AppStyle.icon,
                            ),
                          ),
                          12.horizontalSpace,
                          Container(
                            width: 8.r,
                            height: 8.r,
                            decoration: const BoxDecoration(
                              color: AppStyle.icon,
                              shape: BoxShape.circle,
                            ),
                          ),
                          12.horizontalSpace,
                          Text(
                            TimeService.dateFormatMDYHm(DateTime.parse(
                                    state.selectOrder?.createdAt ?? '')
                                .toLocal()),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500,
                              fontSize: 16.sp,
                              color: AppStyle.icon,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      10.verticalSpace,
                      Text(
                        AppHelpers.getTranslation(TrKeys.totalItem),
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600, fontSize: 18.sp),
                      ),
                      ListView.builder(
                          padding: EdgeInsets.only(top: 16.r, right: 16.r),
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: state.selectOrder?.details?.length ?? 0,
                          itemBuilder: (context, index) {
                            return OrderDetailsItem(
                              orderDetail: state.selectOrder?.details?[index],
                              onEdit: (id, status) {
                                ref
                                    .read(kitchenProvider.notifier)
                                    .changeDetailStatus(status);
                                showDialog(
                                    context: context,
                                    builder: (context) {
                                      return _changeDetailStatusDialog(
                                          status, id, context);
                                    });
                              },
                            );
                          }),
                    ],
                  ),
                  const Divider(),
                  if (state.selectOrder?.note != null)
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppHelpers.getTranslation(TrKeys.note),
                              style: GoogleFonts.inter(
                                color: AppStyle.black,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.4,
                              ),
                            ),
                            Text(
                              state.selectOrder?.note ?? '',
                              style: GoogleFonts.inter(
                                color: AppStyle.black,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                      ],
                    ),
                  8.verticalSpace,
                  if (state.selectOrder?.status != TrKeys.canceled &&
                      state.selectOrder?.status != TrKeys.ready)
                    Column(
                      children: [
                        16.verticalSpace,
                        LoginButton(
                            title: AppHelpers.getTranslation(
                              state.selectOrder?.status == TrKeys.accepted
                                  ? TrKeys.startCooking
                                  : TrKeys.ready,
                            ),
                            onPressed: () {
                              event.changeStatus();
                            }),
                        16.verticalSpace,
                        LoginButton(
                            titleColor: AppStyle.white,
                            title: AppHelpers.getTranslation(TrKeys.cancel),
                            bgColor: AppStyle.red,
                            onPressed: () {
                              AppHelpers.showAlertDialog(
                                context: context,
                                child: Container(
                                  decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(16.r)),
                                  padding: EdgeInsets.all(16.r),
                                  width: 300.r,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "${AppHelpers.getTranslation(TrKeys.areYouSureChange)} ${AppHelpers.getTranslation(TrKeys.cancel)}",
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(),
                                      ),
                                      16.verticalSpace,
                                      Row(
                                        children: [
                                          Expanded(
                                            child: LoginButton(
                                              title: AppHelpers.getTranslation(
                                                  TrKeys.cancel),
                                              onPressed: () {
                                                context.maybePop();
                                              },
                                              bgColor: AppStyle.transparent,
                                            ),
                                          ),
                                          24.horizontalSpace,
                                          Expanded(
                                            child: LoginButton(
                                              title: AppHelpers.getTranslation(
                                                  TrKeys.apply),
                                              onPressed: () {
                                                context.maybePop();
                                                event.changeStatus(
                                                    status: TrKeys.canceled);
                                              },
                                              bgColor: AppStyle.red,
                                              titleColor: AppStyle.white,
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              );
                            }),
                        16.verticalSpace,
                      ],
                    ),
                  if (state.selectOrder?.status == TrKeys.canceled)
                    Center(
                      child: Text(
                        AppHelpers.getTranslation(TrKeys.thisOrderCanceled),
                      ),
                    ),
                  if (state.selectOrder?.status == TrKeys.ready)
                    Center(
                      child: Text(
                        AppHelpers.getTranslation(TrKeys.thisOrderReady),
                      ),
                    )
                ],
              ),
            )
          : Center(
              child: Text(AppHelpers.getTranslation(TrKeys.thereAreNoOrders))),
    );
  }

  AlertDialog _changeDetailStatusDialog(
      String status, int? id, BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.r),
      ),
      content: PopupMenuButton<String>(
        itemBuilder: (context) {
          return [
            PopupMenuItem<String>(
              value: status,
              child: Text(
                AppHelpers.getTranslation(status),
                style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    color: AppStyle.black,
                    fontWeight: FontWeight.w500),
              ),
            ),
            PopupMenuItem<String>(
              value: AppHelpers.getNextOrderStatus(status),
              child: Text(
                AppHelpers.getTranslation(
                    AppHelpers.getNextOrderStatus(status)),
                style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    color: AppStyle.black,
                    fontWeight: FontWeight.w500),
              ),
            ),
            PopupMenuItem<String>(
              value: TrKeys.canceled,
              child: Text(
                AppHelpers.getTranslation(TrKeys.cancel),
                style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    color: AppStyle.black,
                    fontWeight: FontWeight.w500),
              ),
            )
          ];
        },
        onSelected: (s) {
          ref.read(kitchenProvider.notifier).changeDetailStatus(s);
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
        color: AppStyle.white,
        elevation: 10,
        child: Consumer(builder: (context, ref, child) {
          return SelectFromButton(
            title: AppHelpers.getTranslation(
                ref.watch(kitchenProvider).detailStatus),
          );
        }),
      ),
      actionsPadding: REdgeInsets.only(bottom: 16, left: 16, right: 16),
      actions: [
        SizedBox(
          width: 208.w,
          child: ConfirmButton(
              isLoading: ref.watch(kitchenProvider).isUpdatingStatus,
              title: AppHelpers.getTranslation(TrKeys.save),
              onTap: () {
                ref.watch(kitchenProvider).detailStatus == status
                    ? null
                    : ref
                        .read(kitchenProvider.notifier)
                        .updateOrderDetailStatus(
                            status: ref.watch(kitchenProvider).detailStatus,
                            id: id,
                            success: () {
                              Navigator.pop(context);
                            });
              }),
        ),
      ],
    );
  }
}
