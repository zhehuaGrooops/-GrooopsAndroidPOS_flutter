import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/constants.dart';
import '../../../core/utils/utils.dart';
import '../../../models/models.dart';
import '../components.dart';
import '../../theme/theme.dart';

class ProductGridItem extends StatelessWidget {
  final ProductData product;
  final Function() onTap;

  const ProductGridItem({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Stocks? selectedStock = (product.stocks?.isNotEmpty ?? false)
        ? product.stocks?.first
        : product.stock;

    final bool isOutOfStock = (selectedStock?.quantity ?? 0) == 0;
    final bool hasDiscount = isOutOfStock
        ? false
        : (selectedStock?.discount != null &&
            (selectedStock?.discount ?? 0) > 0);
    final String price = isOutOfStock
        ? '0'
        : AppHelpers.numberFormat(
            hasDiscount
                ? ((selectedStock?.price ?? 0) - (selectedStock?.discount ?? 0))
                : selectedStock?.price,
          );
    final lineThroughPrice = isOutOfStock
        ? '0'
        : AppHelpers.numberFormat(
            selectedStock?.price,
          );
    return InkWell(
      borderRadius: BorderRadius.circular(10.r),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.r),
          color: AppStyle.white,
        ),
        constraints: BoxConstraints(
          maxWidth: 227.r,
          maxHeight: 246.r,
        ),
        padding: REdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CommonImage(
                imageUrl: product.img,
              ),
            ),
            16.verticalSpace,
            Text(
              product.translation?.title ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                letterSpacing: -14 * 0.02,
                color: AppStyle.black,
              ),
            ),
            6.verticalSpace,
            Text(
              isOutOfStock
                  ? AppHelpers.getTranslation(TrKeys.outOfStock)
                  : '${AppHelpers.getTranslation(TrKeys.inStock)} - ${selectedStock?.quantity}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                letterSpacing: -14 * 0.02,
                color: isOutOfStock ? AppStyle.red : AppStyle.inStockText,
              ),
            ),
            8.verticalSpace,
            Row(
              children: [
                if (hasDiscount)
                  Row(
                    children: [
                      Text(
                        lineThroughPrice,
                        style: GoogleFonts.inter(
                          decoration: TextDecoration.lineThrough,
                          fontSize: 16.sp,
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
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppStyle.black,
                    letterSpacing: -14 * 0.02,
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
