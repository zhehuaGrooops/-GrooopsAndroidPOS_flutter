import 'package:admin_desktop/src/core/utils/utils.dart';
import 'package:admin_desktop/src/models/response/sale_history_response.dart';
import 'package:admin_desktop/src/presentation/components/buttons/animation_button_effect.dart';
import 'package:admin_desktop/src/presentation/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../../core/constants/constants.dart';

class SaleTab extends StatelessWidget {
  final List<SaleHistoryModel> list;
  final bool isLoading;
  final bool isMoreLoading;
  final bool hasMore;
  final VoidCallback viewMore;
  final ValueChanged<SaleHistoryModel>? onOpenReceipt;
  final ValueChanged<SaleHistoryModel>? onVoid;

  const SaleTab({
    super.key,
    required this.list,
    required this.isLoading,
    required this.hasMore,
    required this.viewMore,
    required this.isMoreLoading,
    this.onOpenReceipt,
    this.onVoid,
  });

  Widget _headerCell(String key) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Text(
        AppHelpers.getTranslation(key),
        style: GoogleFonts.inter(
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          color: AppStyle.black,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _rowCell(Widget child) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 22.r),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.r),
        color: AppStyle.white,
      ),
      child: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppStyle.black),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 1200.w,
                child: Column(
                  children: [
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1), // ID
                        1: FlexColumnWidth(0.6), // Receipt
                        2: FlexColumnWidth(1), // Void
                        3: FlexColumnWidth(1.1), // Client
                        4: FlexColumnWidth(1.1), // Amount
                        5: FlexColumnWidth(1.1), // Payment
                        6: FlexColumnWidth(1.1), // Note
                        7: FlexColumnWidth(1.1), // Date
                      },
                      border: TableBorder.all(color: AppStyle.transparent),
                      children: [
                        TableRow(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(left: 16.w),
                              child: _headerCell(TrKeys.id),
                            ),
                            _headerCell(TrKeys.action),
                            const SizedBox(),
                            _headerCell(TrKeys.client),
                            _headerCell(TrKeys.amount),
                            _headerCell(TrKeys.paymentType),
                            _headerCell(TrKeys.note),
                            _headerCell(TrKeys.date),
                          ],
                        ),
                        for (final sale in list)
                          TableRow(
                            children: [
                              _rowCell(
                                Padding(
                                  padding: EdgeInsets.only(left: 16.w),
                                  child: Text(
                                    "#${sale.id}",
                                    style: GoogleFonts.inter(
                                      fontSize: 14.sp,
                                      color: AppStyle.icon,
                                    ),
                                  ),
                                ),
                              ),
                              _rowCell(
                                SizedBox(
                                  height: 32.r,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppStyle.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8.r),
                                      ),
                                    ),
                                    onPressed: () => onOpenReceipt?.call(sale),
                                    label: Text(
                                      AppHelpers.getTranslation(TrKeys.receipt),
                                      style: GoogleFonts.inter(
                                        fontSize: 12.sp,
                                        color: AppStyle.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              _rowCell(
                                SizedBox(
                                  height: 32.r,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: sale.isVoided == true
                                          ? Colors.grey.shade400
                                          : Colors.redAccent,
                                      disabledBackgroundColor:
                                          Colors.grey.shade400,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8.r),
                                      ),
                                    ),
                                    onPressed: sale.isVoided == true
                                        ? null
                                        : () => onVoid?.call(sale),
                                    child: Text(
                                      'Void Order',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.sp,
                                        color: AppStyle.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              _rowCell(
                                Text(
                                  "${sale.user?.firstname ?? ''} ${sale.user?.lastname ?? ''}",
                                  style: GoogleFonts.inter(
                                    fontSize: 14.sp,
                                    color: AppStyle.icon,
                                  ),
                                ),
                              ),
                              _rowCell(
                                Text(
                                  AppHelpers.numberFormat(sale.totalPrice),
                                  style: GoogleFonts.inter(
                                    fontSize: 14.sp,
                                    color: AppStyle.icon,
                                  ),
                                ),
                              ),
                              _rowCell(
                                Text(
                                  sale.transactions?.isNotEmpty == true
                                      ? AppHelpers.getTranslation(
                                          sale.transactions!.first.paymentSystem
                                                  ?.tag ??
                                              '',
                                        )
                                      : AppHelpers.getTranslation(TrKeys.na),
                                  style: GoogleFonts.inter(
                                    fontSize: 14.sp,
                                    color: AppStyle.icon,
                                  ),
                                ),
                              ),
                              _rowCell(
                                Text(
                                  sale.note ??
                                      AppHelpers.getTranslation(TrKeys.na),
                                  style: GoogleFonts.inter(
                                    fontSize: 14.sp,
                                    color: AppStyle.icon,
                                  ),
                                ),
                              ),
                              _rowCell(
                                Text(
                                  DateFormat('d MMM yyyy HH:mm')
                                      .format(sale.createdAt ?? DateTime.now()),
                                  style: GoogleFonts.inter(
                                    fontSize: 14.sp,
                                    color: AppStyle.icon,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (isMoreLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 18),
                        child: CircularProgressIndicator(
                          color: AppStyle.black,
                        ),
                      )
                    else if (hasMore)
                      InkWell(
                        borderRadius: BorderRadius.circular(10.r),
                        onTap: viewMore,
                        child: AnimationButtonEffect(
                          child: Container(
                            margin: EdgeInsets.symmetric(
                                horizontal: 64.r, vertical: 16.r),
                            height: 50.r,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: AppStyle.black.withOpacity(0.17),
                              ),
                            ),
                            child: Text(
                              AppHelpers.getTranslation(TrKeys.viewMore),
                              style: GoogleFonts.inter(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
