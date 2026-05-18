import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:admin_desktop/src/core/utils/app_helpers.dart';
import 'package:admin_desktop/src/presentation/components/buttons/animation_button_effect.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/kitchen/riverpod/kitchen_notifier.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/kitchen/riverpod/kitchen_provider.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/kitchen/riverpod/kitchen_state.dart';
import 'package:admin_desktop/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../generated/assets.dart';
import 'order_info.dart';
import 'widgets/orders_info.dart';

class KitchenPage extends ConsumerStatefulWidget {
  const KitchenPage({super.key});

  @override
  ConsumerState<KitchenPage> createState() => _KitchenPageState();
}

class _KitchenPageState extends ConsumerState<KitchenPage> {
  List list = [
    TrKeys.all,
    TrKeys.accepted,
    TrKeys.cooking,
    TrKeys.ready,
    TrKeys.canceled,
  ];

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(kitchenProvider.notifier).fetchOrders(isRefresh: true);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final event = ref.read(kitchenProvider.notifier);
    final state = ref.watch(kitchenProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: _ordersList(event, state)),
        const Expanded(flex: 1, child: OrderInfo()),
      ],
    );
  }

  Widget _ordersList(KitchenNotifier event, KitchenState state) => Align(
        alignment: Alignment.topCenter,
        child: ListView(
          padding: EdgeInsets.all(16.r),
          shrinkWrap: true,
          children: [
            Text(
              AppHelpers.getTranslation(TrKeys.orders),
              style: GoogleFonts.inter(
                  fontSize: 22.sp, fontWeight: FontWeight.w600),
            ),
            16.verticalSpace,
            Row(
              children: [
                SvgPicture.asset(Assets.svgMenu),
                8.horizontalSpace,
                ...list.map(
                  (e) => GestureDetector(
                    onTap: () {
                      if (e != state.selectType) {
                        event.changeType(e);
                      }
                    },
                    child: AnimationButtonEffect(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 12.r,
                          horizontal: 18.r,
                        ),
                        margin: EdgeInsets.only(right: 8.r),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.r),
                            color: state.selectType == e
                                ? AppStyle.primary
                                : AppStyle.white),
                        child: Text(
                          AppHelpers.getTranslation(e),
                          style: GoogleFonts.inter(fontSize: 14.sp),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    event.fetchOrders(isRefresh: true);
                  },
                  child: AnimationButtonEffect(
                    child: Container(
                      height: 40.r,
                      width: 40.r,
                      decoration: BoxDecoration(
                          color: AppStyle.white,
                          borderRadius: BorderRadiusDirectional.circular(10)),
                      child: const Icon(FlutterRemix.refresh_line),
                    ),
                  ),
                )
              ],
            ),
            16.verticalSpace,
            state.orders.isNotEmpty
                ? AnimationLimiter(
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisSpacing: 12,
                        crossAxisCount: 3,
                        mainAxisExtent: 224.r,
                      ),
                      itemCount: state.orders.length,
                      itemBuilder: (BuildContext context, int index) {
                        return AnimationConfiguration.staggeredGrid(
                          columnCount: state.orders.length,
                          position: index,
                          duration: const Duration(milliseconds: 375),
                          child: ScaleAnimation(
                            scale: 0.5,
                            child: FadeInAnimation(
                              child: GestureDetector(
                                onTap: () {
                                  if (index != state.selectIndex) {
                                    event.selectIndex(index);
                                  }
                                },
                                child: AnimationButtonEffect(
                                  child: OrdersInfo(
                                    active: state.selectIndex == index,
                                    orderData: state.orders[index],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : state.isLoading
                    ? const SizedBox.shrink()
                    : Center(
                        child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.r),
                        child: Text(
                          AppHelpers.getTranslation(TrKeys.thereAreNoOrders),
                          style: GoogleFonts.inter(
                              fontSize: 20.sp, fontWeight: FontWeight.w600),
                        ),
                      )),
            if (state.isLoading)
              AnimationLimiter(
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisSpacing: 12,
                    crossAxisCount: 3,
                    mainAxisExtent: 270.r,
                  ),
                  itemCount: 9,
                  itemBuilder: (BuildContext context, int index) {
                    return AnimationConfiguration.staggeredGrid(
                      columnCount: 6,
                      position: index,
                      duration: const Duration(milliseconds: 375),
                      child: ScaleAnimation(
                        scale: 0.5,
                        child: FadeInAnimation(
                          child: Container(
                            margin: REdgeInsets.only(bottom: 12),
                            width: 228.w,
                            decoration: BoxDecoration(
                              color: AppStyle.shimmerBase,
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            16.verticalSpace,
            if (state.hasMore)
              Padding(
                padding: REdgeInsets.only(bottom: 24),
                child: GestureDetector(
                  onTap: () => event.fetchOrders(),
                  child: AnimationButtonEffect(
                    child: Container(
                      height: 50.r,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: AppStyle.black.withOpacity(0.17),
                          width: 1.r,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        AppHelpers.getTranslation(TrKeys.viewMore),
                        style: GoogleFonts.inter(
                          fontSize: 16.sp,
                          color: AppStyle.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              )
          ],
        ),
      );
}
