import 'package:admin_desktop/src/presentation/components/buttons/animation_button_effect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/constants/constants.dart';
import '../../../../../core/utils/utils.dart';
import '../../../../components/components.dart';
import '../../../../theme/theme.dart';
import '../../riverpod/provider/main_provider.dart';
import 'page_view_item.dart';
import 'riverpod/right_side_provider.dart';
import 'package:admin_desktop/src/models/models.dart';

class RightSide extends ConsumerStatefulWidget {
  const RightSide({super.key});

  @override
  ConsumerState<RightSide> createState() => _RightSideState();
}

class _RightSideState extends ConsumerState<RightSide> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rightSideProvider.notifier)
        ..fetchBags()
        ..fetchCurrencies(
          checkYourNetwork: () {
            AppHelpers.showSnackBar(
              context,
              AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection),
            );
          },
        )
        ..fetchPayments(
          checkYourNetwork: () {
            AppHelpers.showSnackBar(
              context,
              AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection),
            );
          },
        )
        ..fetchCarts(
          checkYourNetwork: () {
            AppHelpers.showSnackBar(
              context,
              AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection),
            );
          },
        )
        ..fetchSections()
        ..fetchPricingTiers(context);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rightSideProvider);
    final notifier = ref.read(rightSideProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56.r,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  itemCount: state.bags.length,
                  itemBuilder: (context, index) {
                    final bag = state.bags[index];
                    final bool isSelected = state.selectedBagIndex == index;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(10.r),
                          onTap: () {
                            notifier.setSelectedBagIndex(index);
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.ease,
                            );
                          },
                          child: Container(
                            height: 56.r,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10.r),
                              color: isSelected
                                  ? AppStyle.white
                                  : AppStyle.transparent,
                            ),
                            padding: REdgeInsets.only(
                              left: 20,
                              right: index == 0 ? 20 : 4,
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  FlutterRemix.shopping_bag_3_fill,
                                  size: 20.r,
                                  color: isSelected
                                      ? AppStyle.black
                                      : AppStyle.unselectedTab,
                                ),
                                8.horizontalSpace,
                                Text(
                                  '${AppHelpers.getTranslation(TrKeys.bag)} - ${(bag.index ?? 0) + 1}',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14.sp,
                                    color: isSelected
                                        ? AppStyle.black
                                        : AppStyle.unselectedTab,
                                    letterSpacing: -14 * 0.02,
                                  ),
                                ),
                                if (index != 0)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      16.horizontalSpace,
                                      CircleIconButton(
                                        backgroundColor: AppStyle.transparent,
                                        iconData: FlutterRemix.close_line,
                                        iconColor: isSelected
                                            ? AppStyle.black
                                            : AppStyle.unselectedTab,
                                        onTap: () => notifier.removeBag(index),
                                        size: 30,
                                      )
                                    ],
                                  )
                              ],
                            ),
                          ),
                        ),
                        4.horizontalSpace,
                      ],
                    );
                  },
                ),
              ),
            ),
            9.horizontalSpace,
            InkWell(
              onTap: notifier.addANewBag,
              child: AnimationButtonEffect(
                child: Container(
                  width: 52.r,
                  height: 52.r,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.r),
                    color: AppStyle.white,
                  ),
                  child: const Center(child: Icon(FlutterRemix.add_line)),
                ),
              ),
            ),
          ],
        ),
        6.verticalSpace,
        const _FilterPanel(),
        8.verticalSpace,
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppStyle.white,
              borderRadius: BorderRadius.circular(10.r),
            ),
            clipBehavior: Clip.antiAlias,
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children:
                  state.bags.map((bag) => PageViewItem(bag: bag)).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterPanel extends ConsumerWidget {
  const _FilterPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricingTiers = ref.watch(pricingTiersProvider);
    final selectedTier = ref.watch(selectedPricingTierProvider);
    // final price = ref.watch(mainProvider);

    DropdownButtonFormField<ProductPricingTier?> compactField({
      required String label,
      required ProductPricingTier? value,
      required List<DropdownMenuItem<ProductPricingTier?>> items,
      required void Function(ProductPricingTier? v) onChanged,
    }) {
      return DropdownButtonFormField<ProductPricingTier?>(
        value: value,
        isDense: true,
        icon: const Icon(FlutterRemix.arrow_down_s_line, size: 16),
        style: GoogleFonts.inter(fontSize: 12.sp, color: AppStyle.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(
            fontSize: 11.sp,
            color: AppStyle.black.withOpacity(0.6),
          ),
          isDense: true,
          contentPadding: REdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.2),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.2),
            ),
          ),
        ),
        items: items,
        onChanged: onChanged,
      );
    }

    final pricingItems = [
      const DropdownMenuItem<ProductPricingTier?>(
        value: null,
        child: Text('Default'),
      ),
      ...pricingTiers.map((tier) {
        return DropdownMenuItem<ProductPricingTier?>(
          value: tier,
          child: Text(tier.title ?? ''),
        );
      }),
    ];

    final resetBtn = IconButton(
      tooltip: 'Reset',
      onPressed: () {
        ref.read(selectedPricingTierProvider.notifier).state = null;
        ref.read(mainProvider.notifier).refreshProducts(context: context);
      },
      icon: const Icon(FlutterRemix.refresh_line, size: 18),
      splashRadius: 18,
    );

    return Container(
      padding: REdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppStyle.white,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double minFieldWidth = 160;
          final bool sideBySide = constraints.maxWidth >= (minFieldWidth + 40);

          if (!sideBySide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                compactField(
                  label: 'Pricing tier',
                  value: selectedTier,
                  items: pricingItems,
                  onChanged: (v) async {
                    ref.read(selectedPricingTierProvider.notifier).state = v;
                    // First fetch tier prices and update cart state
                    await ref
                        .read(rightSideProvider.notifier)
                        .fetchAndUpdateTierPrices(v);
                    // After tierPrices are fetched and stored in RightSideState,
                    // read them and pass to refreshProducts so the product grid
                    // immediately shows overridden prices.
                    final tierPrices = ref.read(rightSideProvider).tierPrices;
                    ref.read(mainProvider.notifier).refreshProducts(
                          context: null,
                          pricingTier: v,
                          tierPrices: tierPrices.isNotEmpty ? tierPrices : null,
                        );
                  },
                ),
                Align(alignment: Alignment.centerRight, child: resetBtn),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: compactField(
                  label: 'Pricing tier',
                  value: selectedTier,
                  items: pricingItems,
                  onChanged: (v) async {
                    ref.read(selectedPricingTierProvider.notifier).state = v;
                    await ref
                        .read(rightSideProvider.notifier)
                        .fetchAndUpdateTierPrices(v);
                    final tierPrices = ref.read(rightSideProvider).tierPrices;
                    ref.read(mainProvider.notifier).refreshProducts(
                          context: null,
                          pricingTier: v,
                          tierPrices: tierPrices.isNotEmpty ? tierPrices : null,
                        );
                  },
                ),
              ),
              8.horizontalSpace,
            ],
          );
        },
      ),
    );
  }
}
