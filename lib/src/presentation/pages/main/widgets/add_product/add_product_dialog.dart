import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/constants/constants.dart';
import '../../../../../core/utils/utils.dart';
import '../../../../../models/models.dart';
import '../../../../components/components.dart';
import '../../../../theme/theme.dart';
import '../right_side/riverpod/right_side_provider.dart';
import 'provider/add_product_provider.dart';
import 'widgets/extras/color_extras.dart';
import 'widgets/extras/image_extras.dart';
import 'widgets/extras/text_extras.dart';
import 'widgets/w_ingredient.dart';

class AddProductDialog extends ConsumerStatefulWidget {
  final ProductData? product;

  const AddProductDialog({super.key, required this.product});

  @override
  ConsumerState<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends ConsumerState<AddProductDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(addProductProvider.notifier).setProduct(
            widget.product,
            ref.watch(rightSideProvider).selectedBagIndex,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addProductProvider);
    final rightSideState = ref.watch(rightSideProvider);
    final notifier = ref.read(addProductProvider.notifier);
    final rightSideNotifier = ref.read(rightSideProvider.notifier);
    final user = LocalStorage.getUser();
    final int shopId = user?.role == TrKeys.waiter
        ? user?.invite?.shopId ?? 0
        : user?.shop?.id ?? 0;
    final bool canAddProduct = user?.role != TrKeys.admin && shopId != 0;

    Stocks? selectedStock = (state.product?.stocks?.isNotEmpty ?? false)
        ? state.product?.stocks?.first
        : state.product?.stock;
    if ((selectedStock?.quantity ?? 0) == 0) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.r),
            color: AppStyle.white,
          ),
          constraints: BoxConstraints(
            maxHeight: 700.r,
            maxWidth: 600.r,
          ),
          padding: REdgeInsets.symmetric(horizontal: 40, vertical: 50),
          child: Text(
            '${state.product?.translation?.title} ${AppHelpers.getTranslation(TrKeys.outOfStock).toLowerCase()}',
          ),
        ),
      );
    }
    final bool hasDiscount = (state.selectedStock?.discount != null &&
        (state.selectedStock?.discount ?? 0) > 0);
    num addonsPrice = 0;
    if (state.selectedStock?.addons != null) {
      for (var addon in state.selectedStock!.addons!) {
        if (addon.active ?? false) {
          addonsPrice += (addon.price ?? 0) * (addon.quantity ?? 0);
        }
      }
    }
    final String price = AppHelpers.numberFormat(
      ((hasDiscount
                  ? (state.selectedStock?.totalPrice ?? 0)
                  : (state.selectedStock?.price ?? 0)) +
              addonsPrice) *
          state.stockCount,
    );
    final lineThroughPrice = AppHelpers.numberFormat(
      ((state.selectedStock?.price ?? 0) + addonsPrice) * state.stockCount,
    );
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.r),
          color: AppStyle.white,
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height / 1.6,
          maxWidth: MediaQuery.of(context).size.width / 1.6,
        ),
        padding: REdgeInsets.symmetric(horizontal: 40),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              20.verticalSpace,
              Row(
                children: [
                  const SizedBox.shrink(),
                  const Spacer(),
                  CircleIconButton(
                    size: 60,
                    backgroundColor: AppStyle.transparent,
                    iconData: FlutterRemix.close_circle_line,
                    iconColor: AppStyle.black,
                    onTap: context.maybePop,
                  ),
                ],
              ),
              6.verticalSpace,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CommonImage(
                        imageUrl: widget.product?.img,
                        width: 250,
                        height: 250,
                      ),
                      24.verticalSpace,
                      Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6.r),
                            border: Border.all(color: AppStyle.icon)),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => notifier.decreaseStockCount(
                                  rightSideState.selectedBagIndex),
                              icon: const Icon(FlutterRemix.subtract_line),
                            ),
                            13.horizontalSpace,
                            Text(
                              '${state.stockCount}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 18.sp,
                                color: AppStyle.black,
                                letterSpacing: -0.4,
                              ),
                            ),
                            12.horizontalSpace,
                            IconButton(
                              onPressed: () => notifier.increaseStockCount(
                                  rightSideState.selectedBagIndex),
                              icon: const Icon(FlutterRemix.add_line),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  32.horizontalSpace,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          widget.product?.translation?.title ?? '',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 22.sp,
                            color: AppStyle.black,
                            letterSpacing: -0.4,
                          ),
                        ),
                        8.verticalSpace,
                        Text(
                          widget.product?.translation?.description ?? '',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w500,
                            fontSize: 16.sp,
                            color: AppStyle.icon,
                            letterSpacing: -0.4,
                          ),
                        ),
                        8.verticalSpace,
                        SizedBox(
                          width:
                              MediaQuery.of(context).size.width / 1.6 - 370.w,
                          child: Divider(
                            color: AppStyle.black.withOpacity(0.2),
                          ),
                        ),
                        SizedBox(
                          width:
                              MediaQuery.of(context).size.width / 1.6 - 370.w,
                          child: ListView.builder(
                            physics: const CustomBouncingScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: state.typedExtras.length,
                            padding: EdgeInsets.zero,
                            itemBuilder: (context, index) {
                              final TypedExtra typedExtra =
                                  state.typedExtras[index];
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8.r),
                                  color: AppStyle.white,
                                ),
                                padding: REdgeInsets.symmetric(vertical: 6),
                                margin: REdgeInsets.only(bottom: 6),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      typedExtra.title,
                                      style: GoogleFonts.inter(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                        color: AppStyle.black,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    8.verticalSpace,
                                    typedExtra.type == ExtrasType.text
                                        ? TextExtras(
                                            uiExtras: typedExtra.uiExtras,
                                            groupIndex: typedExtra.groupIndex,
                                            onUpdate: (s) {
                                              notifier.updateSelectedIndexes(
                                                index: typedExtra.groupIndex,
                                                value: s.index,
                                                bagIndex: rightSideState
                                                    .selectedBagIndex,
                                              );
                                            },
                                          )
                                        : typedExtra.type == ExtrasType.color
                                            ? ColorExtras(
                                                uiExtras: typedExtra.uiExtras,
                                                groupIndex:
                                                    typedExtra.groupIndex,
                                              )
                                            : typedExtra.type ==
                                                    ExtrasType.image
                                                ? ImageExtras(
                                                    uiExtras:
                                                        typedExtra.uiExtras,
                                                    groupIndex:
                                                        typedExtra.groupIndex,
                                                  )
                                                : const SizedBox(),
                                    8.verticalSpace,
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width /
                                              1.6 -
                                          370.w,
                                      child: Divider(
                                        color: AppStyle.black.withOpacity(0.2),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        8.verticalSpace,
                        SizedBox(
                          width:
                              MediaQuery.of(context).size.width / 1.6 - 370.w,
                          child: WIngredientScreen(
                            list: state.selectedStock?.addons ?? [],
                            onChange: (int value) {
                              notifier.updateIngredient(context, value);
                            },
                            add: (int value) {
                              notifier.addIngredient(context, value);
                            },
                            remove: (int value) {
                              notifier.removeIngredient(context, value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              10.verticalSpace,
              const Divider(),
              10.verticalSpace,
              Row(
                children: [
                  SizedBox(
                    width: 120.w,
                    child: LoginButton(
                      isActive: canAddProduct,
                      isLoading: state.isLoading,
                      title: AppHelpers.getTranslation(TrKeys.add),
                      onPressed: () {
                        if (canAddProduct) {
                          notifier.addProductToBag(
                            context,
                            rightSideState.selectedBagIndex,
                            rightSideNotifier,
                          );
                          context.maybePop();
                        }
                      },
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${AppHelpers.getTranslation(TrKeys.price)}:',
                        style: GoogleFonts.inter(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: AppStyle.black,
                          letterSpacing: -14 * 0.02,
                        ),
                      ),
                      4.verticalSpace,
                      Row(
                        children: [
                          if (hasDiscount)
                            Row(
                              children: [
                                Text(
                                  lineThroughPrice,
                                  style: GoogleFonts.inter(
                                    decoration: TextDecoration.lineThrough,
                                    fontSize: 32.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppStyle.discountText,
                                    letterSpacing: -14 * 0.02,
                                  ),
                                ),
                                10.horizontalSpace,
                              ],
                            ),
                          Text(
                            price,
                            style: GoogleFonts.inter(
                              fontSize: 32.sp,
                              fontWeight: FontWeight.w600,
                              color: AppStyle.black,
                              letterSpacing: -14 * 0.02,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              20.verticalSpace,
            ],
          ),
        ),
      ),
    );
  }
}
