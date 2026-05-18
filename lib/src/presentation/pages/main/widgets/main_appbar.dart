import 'package:admin_desktop/generated/assets.dart';
import 'package:admin_desktop/src/presentation/components/category_tab_bar_item.dart';
import 'package:admin_desktop/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/utils/utils.dart';
import '../riverpod/provider/main_provider.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/right_side/riverpod/right_side_provider.dart';

class MainAppbar extends ConsumerWidget {
  const MainAppbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(mainProvider.notifier);
    final state = ref.watch(mainProvider);

    // Add these lines to get the current pricing tier and prices
    final selectedTier = ref.watch(selectedPricingTierProvider);
    final tierPrices = ref.watch(rightSideProvider.select((s) => s.tierPrices));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        state.categories.isEmpty
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                        color: AppStyle.white,
                        borderRadius: BorderRadius.circular(10.r)),
                    height: 56.h,
                    child: ListView.builder(
                        shrinkWrap: true,
                        scrollDirection: Axis.horizontal,
                        itemCount: state.categories.length + 2,
                        itemBuilder: (context, index) {
                          return index == 0
                              ? Padding(
                                  padding: EdgeInsets.only(right: 6.r),
                                  child: SvgPicture.asset(Assets.svgMenu),
                                )
                              : index == 1
                                  ? CategoryTabBarItem(
                                      isActive:
                                          state.selectedCategory?.id == null,
                                      onTap: () {
                                        notifier.setSelectedCategory(
                                          context,
                                          -1,
                                          pricingTier: selectedTier,
                                          tierPrices: tierPrices,
                                        );
                                      },
                                      title:
                                          AppHelpers.getTranslation(TrKeys.all),
                                    )
                                  : CategoryTabBarItem(
                                      isActive:
                                          state.categories[index - 2].id ==
                                              state.selectedCategory?.id,
                                      onTap: () {
                                        notifier.setSelectedCategory(
                                          context,
                                          index - 2,
                                          pricingTier: selectedTier,
                                          tierPrices: tierPrices,
                                        );
                                      },
                                      title: state.categories[index - 2]
                                          .translation?.title,
                                    );
                        }),
                  )
                ],
              )
      ],
    );
  }
}
