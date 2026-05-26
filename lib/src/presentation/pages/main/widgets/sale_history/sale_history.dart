import 'package:admin_desktop/generated/assets.dart';
import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:admin_desktop/src/core/utils/app_helpers.dart';
import 'package:admin_desktop/src/core/utils/utils.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/sale_history/riverpod/sale_history_notifier.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/sale_history/riverpod/sale_history_state.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/sale_history/sale_tab.dart';
import 'package:admin_desktop/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:admin_desktop/src/core/di/dependency_manager.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/right_side/riverpod/right_side_provider.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/order_calculate/generate_check.dart';

import '../../../../components/components.dart';
import 'riverpod/sale_history_provider.dart';

class SaleHistory extends ConsumerStatefulWidget {
  const SaleHistory({super.key});

  @override
  ConsumerState<SaleHistory> createState() => _SaleHistoryState();
}

class _SaleHistoryState extends ConsumerState<SaleHistory> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(saleHistoryProvider.notifier)
        ..fetchSale()
        ..fetchSaleCarts();
    });
  }

  Future<bool> _confirmVoid(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              title: Text(
                AppHelpers.getTranslation(TrKeys.confirm),
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              content: Text(
                'Are you sure you want to void this order?',
                style: GoogleFonts.inter(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    AppHelpers.getTranslation(TrKeys.cancel),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    AppHelpers.getTranslation(TrKeys.confirm),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(saleHistoryProvider);
    final event = ref.read(saleHistoryProvider.notifier);
    return ListView(
      padding: EdgeInsets.symmetric(vertical: 20.r, horizontal: 16.r),
      shrinkWrap: true,
      children: [
        Text(
          AppHelpers.getTranslation(TrKeys.saleHistory),
          style: GoogleFonts.inter(fontSize: 22.r, fontWeight: FontWeight.w600),
        ),
        16.verticalSpace,
        _topWidgets(state, event),
        if (state.errorMessage != null)
          Padding(
            padding: EdgeInsets.only(top: 16.r),
            child: Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  12.horizontalSpace,
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: GoogleFonts.inter(color: Colors.red),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.red),
                    onPressed: () {
                      event.fetchSale();
                      event.fetchSaleCarts();
                    },
                  ),
                ],
              ),
            ),
          ),
        16.verticalSpace,
        if (state.selectIndex == 2) _saleCarts(state),
        16.verticalSpace,
        SaleTab(
          isMoreLoading: state.isMoreLoading,
          isLoading: state.isLoading,
          list: state.selectIndex == 0
              ? state.listDriver
              : state.selectIndex == 1
                  ? state.listToday
                  : state.listHistory,
          hasMore: state.hasMore,
          viewMore: () {
            event.fetchSalePage();
          },
          onOpenReceipt: (sale) async {
            ref.read(rightSideProvider);
            if (!context.mounted) return;
            showDialog(
                context: context,
                builder: (context) {
                  return Dialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: SizedBox(
                      width: 380.w,
                      child: GenerateReceiptPage(
                        orderId: sale.id!.toString(),
                        isKitchen: false,
                      ),
                    ),
                  );
                });
          },
          onVoid: (sale) async {
            final confirmed = await _confirmVoid(context);
            if (!confirmed) return;

            final result =
                await ordersRepository.setOrderVoided(orderId: sale.id!);

            result.when(
              success: (_) {
                event.fetchSale();
                event.fetchSaleCarts();
              },
              failure: (err, status) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err)),
                );
              },
            );
          },
        )
      ],
    );
  }

  Widget _saleCarts(SaleHistoryState state) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20.r, vertical: 30.r),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.r),
                color: AppStyle.white),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppHelpers.getTranslation(TrKeys.openingDrawerAmount),
                      style: GoogleFonts.inter(fontSize: 16.sp),
                    ),
                    20.verticalSpace,
                    Text(
                      AppHelpers.numberFormat(
                        state.saleCart?.deliveryFee ?? 0,
                      ),
                      style: GoogleFonts.inter(
                          fontSize: 24.sp, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppStyle.primary.withOpacity(0.01),
                        boxShadow: [
                          BoxShadow(
                              blurRadius: 32.r,
                              spreadRadius: 12.r,
                              color: AppStyle.primary.withOpacity(0.5))
                        ]),
                    child: SvgPicture.asset(Assets.svgCart))
              ],
            ),
          ),
        ),
        12.horizontalSpace,
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20.r, vertical: 30.r),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.r),
                color: AppStyle.white),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppHelpers.getTranslation(TrKeys.cashPaymentSale),
                      style: GoogleFonts.inter(fontSize: 16.sp),
                    ),
                    20.verticalSpace,
                    Text(
                      AppHelpers.numberFormat(
                        state.saleCart?.cash ?? 0,
                      ),
                      style: GoogleFonts.inter(
                          fontSize: 24.sp, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppStyle.starColor.withOpacity(0.01),
                        boxShadow: [
                          BoxShadow(
                              blurRadius: 32.r,
                              spreadRadius: 12.r,
                              color: AppStyle.starColor.withOpacity(0.5))
                        ]),
                    child: SvgPicture.asset(Assets.svgDollar))
              ],
            ),
          ),
        ),
        12.horizontalSpace,
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20.r, vertical: 30.r),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.r),
                color: AppStyle.white),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppHelpers.getTranslation(TrKeys.otherPaymentSale),
                      style: GoogleFonts.inter(fontSize: 16.sp),
                    ),
                    20.verticalSpace,
                    Text(
                      AppHelpers.numberFormat(
                        state.saleCart?.other ?? 0,
                      ),
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 24.sp),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppStyle.blue.withOpacity(0.01),
                        boxShadow: [
                          BoxShadow(
                              blurRadius: 32.r,
                              spreadRadius: 12.r,
                              color: AppStyle.blue.withOpacity(0.5))
                        ]),
                    child: SvgPicture.asset(Assets.svgCart2))
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _topWidgets(SaleHistoryState state, SaleHistoryNotifier notifier) {
    List statusList = [TrKeys.cashDrawer, TrKeys.todaySale, TrKeys.saleHistory];
    return Row(
      children: [
        SvgPicture.asset(Assets.svgMenu),
        for (int i = 0; i < statusList.length; i++)
          Padding(
            padding: REdgeInsets.only(left: 8),
            child: ConfirmButton(
              paddingSize: 18,
              textSize: 14,
              isActive: state.selectIndex == i,
              title: AppHelpers.getTranslation(statusList[i]),
              textColor: AppStyle.black,
              isTab: true,
              isShadow: true,
              onTap: () => notifier.changeIndex(i),
            ),
          )
      ],
    );
  }
}
