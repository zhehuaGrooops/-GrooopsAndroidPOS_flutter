// ignore_for_file: unrelated_type_equality_checks

import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/widgets/table_order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../core/constants/constants.dart';
import '../../../../../../core/utils/utils.dart';
import '../../../../../components/buttons/animation_button_effect.dart';
import '../../../../../components/components.dart';
import '../../../../../theme/theme.dart';
import '../riverpod/tables_notifier.dart';
import '../riverpod/tables_provider.dart';
import '../riverpod/tables_state.dart';
import 'custom_refresher.dart';

class TablesList extends ConsumerWidget {
  const TablesList({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final state = ref.watch(tablesProvider);
    final notifier = ref.read(tablesProvider.notifier);
    return Column(
      children: [
        _topWidgets(ref.watch(tablesProvider),
            ref.read(tablesProvider.notifier), context),
        8.verticalSpace,
        Expanded(
          child: _bodyWidgets(state, notifier),
        ),
      ],
    );
  }

  Widget _bodyWidgets(TablesState state, TablesNotifier notifier) {
    return ListView(
      padding: REdgeInsets.only(top: 8),
      children: [
        state.tableBookingData.isNotEmpty
            ? AnimationLimiter(
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisSpacing: 12,
                      crossAxisCount: 3,
                      mainAxisExtent: 270.r),
                  itemCount: state.tableBookingData.length,
                  itemBuilder: (BuildContext context, int index) {
                    return AnimationConfiguration.staggeredGrid(
                      columnCount: state.tableBookingData.length,
                      position: index,
                      duration: const Duration(milliseconds: 375),
                      child: ScaleAnimation(
                        scale: 0.5,
                        child: FadeInAnimation(
                          child: GestureDetector(
                            onTap: () {
                              if (index != state.selectOrderIndex) {
                                notifier.changeSelectOrder(index);
                              }
                            },
                            child: AnimationButtonEffect(
                              child: TableOrder(
                                active: state.selectOrderIndex == index,
                                tableBookingData: state.tableBookingData[index],
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
                  mainAxisExtent: 270.r),
              itemCount: 6,
              itemBuilder: (BuildContext context, int index) {
                return AnimationConfiguration.staggeredGrid(
                  columnCount: 6,
                  position: index,
                  duration: const Duration(milliseconds: 375),
                  child: ScaleAnimation(
                    scale: 0.5,
                    child: FadeInAnimation(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        width: 228.w,
                        decoration: BoxDecoration(
                          color: AppStyle.shimmerBase,
                          borderRadius: BorderRadiusDirectional.circular(10),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        if (state.isLoading)
          const Center(
            child: CircularProgressIndicator(
              color: AppStyle.primary,
            ),
          ),
      ],
    );
  }

  Widget _topWidgets(
      TablesState state, TablesNotifier notifier, BuildContext context) {
    List statusList = [
      TrKeys.all,
      TrKeys.newKey,
      TrKeys.accepted,
      TrKeys.canceled,
    ];
    return Row(
      children: [
        for (int i = 0; i < statusList.length; i++)
          Padding(
            padding: REdgeInsets.only(left: 8),
            child: ConfirmButton(
              paddingSize: 18,
              textSize: 14,
              isActive: state.selectListTabIndex == i,
              title: AppHelpers.getTranslation(statusList[i]),
              textColor: AppStyle.black,
              isTab: true,
              isShadow: true,
              onTap: () => notifier.changeListTabIndex(i),
            ),
          ),
        const Spacer(),
        CustomRefresher(
          onTap: () => notifier.changeListTabIndex(state.selectListTabIndex),
          isLoading: state.isLoading,
        )
      ],
    );
  }
}
