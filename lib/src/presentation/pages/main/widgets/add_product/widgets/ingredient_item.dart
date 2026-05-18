import 'package:admin_desktop/src/core/utils/app_helpers.dart';
import 'package:admin_desktop/src/models/data/addons_data.dart';
import 'package:admin_desktop/src/presentation/components/custom_checkbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../theme/app_style.dart';

class IngredientItem extends ConsumerWidget {
  final VoidCallback onTap;
  final VoidCallback add;
  final VoidCallback remove;
  final Addons addon;

  const IngredientItem({
    required this.add,
    required this.remove,
    super.key,
    required this.onTap,
    required this.addon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        onTap();
      },
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(vertical: 10.r),
        decoration: BoxDecoration(
            color: AppStyle.white,
            borderRadius: BorderRadius.all(Radius.circular(10.r))),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CustomCheckbox(
                  isActive: addon.active ?? false,
                  onTap: onTap,
                ),
                10.horizontalSpace,
                (addon.active ?? false)
                    ? Row(
                        children: [
                          InkWell(
                            onTap: remove,
                            child: Container(
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppStyle.removeButtonColor),
                              child: Icon(
                                Icons.remove,
                                color: (addon.quantity ?? 1) == 1
                                    ? AppStyle.outlineButtonBorder
                                    : AppStyle.black,
                              ),
                            ),
                          ),
                          8.horizontalSpace,
                          Text(
                            "${addon.quantity ?? 1}",
                            style: GoogleFonts.inter(
                              fontSize: 16.sp,
                            ),
                          ),
                          8.horizontalSpace,
                          InkWell(
                            onTap: add,
                            child: Container(
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppStyle.addButtonColor),
                              child: const Icon(
                                Icons.add,
                                color: AppStyle.black,
                              ),
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
                16.horizontalSpace,
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        addon.product?.translation?.title ?? "",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppStyle.black,
                        ),
                      ),
                      4.horizontalSpace,
                      Text(
                        "+${AppHelpers.numberFormat(
                          addon.price ?? 0,
                        )}",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppStyle.hint,
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
