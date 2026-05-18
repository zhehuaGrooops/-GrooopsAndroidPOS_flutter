import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:admin_desktop/src/core/utils/app_helpers.dart';
import 'package:admin_desktop/src/models/data/order_data.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/order_detail/widgets/product_table.dart';
import 'package:admin_desktop/src/presentation/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class ProductsScreen extends StatelessWidget {
  final OrderData? orderData;
  final num subTotal;
  final Function(int?, String) onEdit;

  const ProductsScreen({
    super.key,
    required this.orderData,
    required this.subTotal,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppStyle.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppStyle.border),
      ),
      padding: EdgeInsets.all(24.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppHelpers.getTranslation(TrKeys.compositionOrder),
            style:
                GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18.sp),
          ),
          18.verticalSpace,
          ProductTable(
            orderData: orderData,
            onEdit: onEdit,
          ),
        ],
      ),
    );
  }
}
