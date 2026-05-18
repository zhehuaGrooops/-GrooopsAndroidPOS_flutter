// ignore_for_file: depend_on_referenced_packages

import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:admin_desktop/src/core/utils/app_helpers.dart';
import 'package:admin_desktop/src/core/utils/utils.dart';
import 'package:admin_desktop/src/models/data/addons_data.dart';
import 'package:admin_desktop/src/models/data/order_data.dart';
import 'package:admin_desktop/src/presentation/components/components.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/order_detail/print_page.dart';
import 'package:admin_desktop/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class GenerateCheckPage extends StatefulWidget {
  final OrderData? orderData;

  const GenerateCheckPage({super.key, required this.orderData});

  @override
  State<GenerateCheckPage> createState() => _GenerateCheckPageState();
}

class _GenerateCheckPageState extends State<GenerateCheckPage> {
  @override
  Widget build(BuildContext context) {
    num subTotal = 0;
    subTotal = ((widget.orderData?.totalPrice ?? 0) -
        (widget.orderData?.tax ?? 0) -
        (widget.orderData?.deliveryFee ?? 0) +
        (widget.orderData?.totalDiscount ?? 0));
    return Container(
      decoration: BoxDecoration(
          color: AppStyle.white, borderRadius: BorderRadius.circular(10.r)),
      padding: EdgeInsets.all(16.r),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            24.verticalSpace,
            Text(
              AppHelpers.getTranslation(TrKeys.orderSummary),
              style: GoogleFonts.inter(
                  fontSize: 22.sp, fontWeight: FontWeight.w600),
            ),
            8.verticalSpace,
            Text(
              "${AppHelpers.getTranslation(TrKeys.order)} #${AppHelpers.getTranslation(TrKeys.id)}${widget.orderData?.id}",
              style: GoogleFonts.inter(
                  fontSize: 16.sp, fontWeight: FontWeight.w500),
            ),
            12.verticalSpace,
            Row(
              children: List.generate(
                  20,
                  (index) => Expanded(
                        child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 4.r),
                            height: 2,
                            color: AppStyle.iconButtonBack),
                      )),
            ),
            12.verticalSpace,
            Row(
              children: [
                SizedBox(
                  width: 100.w,
                  child: Text(
                    AppHelpers.getTranslation(TrKeys.shopName),
                    style: GoogleFonts.inter(
                        fontSize: 14.sp, fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  widget.orderData?.shop?.translation?.title ?? "",
                  style: GoogleFonts.inter(
                      fontSize: 14.sp, fontWeight: FontWeight.w400),
                )
              ],
            ),
            8.verticalSpace,
            if (widget.orderData?.table?.name != null)
              Row(
                children: [
                  SizedBox(
                    width: 100.w,
                    child: Text(
                      AppHelpers.getTranslation(TrKeys.tableName),
                      style: GoogleFonts.inter(
                          fontSize: 14.sp, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    widget.orderData?.table?.name ?? "",
                    style: GoogleFonts.inter(
                        fontSize: 14.sp, fontWeight: FontWeight.w400),
                  )
                ],
              ),
            8.verticalSpace,
            Row(
              children: [
                SizedBox(
                  width: 100.w,
                  child: Text(
                    AppHelpers.getTranslation(TrKeys.client),
                    style: GoogleFonts.inter(
                        fontSize: 14.sp, fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  "${widget.orderData?.user?.firstname ?? ""} ${widget.orderData?.user?.lastname ?? ""}",
                  style: GoogleFonts.inter(
                      fontSize: 14.sp, fontWeight: FontWeight.w400),
                )
              ],
            ),
            8.verticalSpace,
            Row(
              children: [
                SizedBox(
                  width: 100.w,
                  child: Text(
                    AppHelpers.getTranslation(TrKeys.date),
                    style: GoogleFonts.inter(
                        fontSize: 14.sp, fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  widget.orderData?.createdAt ?? "",
                  style: GoogleFonts.inter(
                      fontSize: 10.sp, fontWeight: FontWeight.w400),
                )
              ],
            ),
            10.verticalSpace,
            Divider(
              thickness: 2.r,
            ),
            ListView.builder(
                padding: EdgeInsets.only(top: 16.r),
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: widget.orderData?.details?.length ?? 0,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 16.r),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${widget.orderData?.details?[index].stock?.product?.translation?.title ?? ""} x ${widget.orderData?.details?[index].quantity ?? ""}",
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.sp,
                                      color: AppStyle.black),
                                ),
                                6.verticalSpace,
                                for (Addons e in (widget
                                        .orderData?.details?[index].addons ??
                                    []))
                                  Text(
                                    "${e.stocks?.product?.translation?.title ?? ""} ( ${AppHelpers.numberFormat(
                                      (e.price ?? 0) / (e.quantity ?? 1),
                                      symbol:
                                          widget.orderData?.currency?.symbol ??
                                              "",
                                    )} x ${(e.quantity ?? 1)} )",
                                    style: GoogleFonts.inter(
                                      fontSize: 14.sp,
                                      color: AppStyle.unselectedTab,
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              AppHelpers.numberFormat(
                                widget.orderData?.details?[index].totalPrice ??
                                    0,
                                symbol: widget.orderData?.currency?.symbol,
                              ),
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14.sp,
                                  color: AppStyle.black),
                            )
                          ],
                        ),
                        10.verticalSpace,
                        Row(
                          children: List.generate(
                              20,
                              (index) => Expanded(
                                    child: Container(
                                        margin: EdgeInsets.symmetric(
                                            horizontal: 4.r),
                                        height: 2,
                                        color: AppStyle.iconButtonBack),
                                  )),
                        )
                      ],
                    ),
                  );
                }),
            Row(
              children: List.generate(
                  20,
                  (index) => Expanded(
                        child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 4.r),
                            height: 2,
                            color: AppStyle.iconButtonBack),
                      )),
            ),
            20.verticalSpace,
            Row(
              children: [
                Text(
                  AppHelpers.getTranslation(TrKeys.subtotal),
                  style: GoogleFonts.inter(
                      fontSize: 14.sp, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  AppHelpers.numberFormat(
                    subTotal,
                  ),
                  style: GoogleFonts.inter(
                      fontSize: 14.sp, fontWeight: FontWeight.w400),
                )
              ],
            ),
            10.verticalSpace,
            Row(
              children: [
                Text(
                  AppHelpers.getTranslation(TrKeys.tax),
                  style: GoogleFonts.inter(
                      fontSize: 14.sp, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  AppHelpers.numberFormat(
                    widget.orderData?.tax ?? 0,
                  ),
                  style: GoogleFonts.inter(
                      fontSize: 14.sp, fontWeight: FontWeight.w400),
                )
              ],
            ),
            10.verticalSpace,
            Row(
              children: [
                Text(
                  AppHelpers.getTranslation(TrKeys.deliveryFee),
                  style: GoogleFonts.inter(
                      fontSize: 14.sp, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  AppHelpers.numberFormat(
                    widget.orderData?.deliveryFee ?? 0,
                  ),
                  style: GoogleFonts.inter(
                      fontSize: 14.sp, fontWeight: FontWeight.w400),
                )
              ],
            ),
            10.verticalSpace,
            Row(
              children: [
                Text(
                  AppHelpers.getTranslation(TrKeys.discount),
                  style: GoogleFonts.inter(
                      fontSize: 14.sp, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  AppHelpers.numberFormat(
                    widget.orderData?.totalDiscount ?? 0,
                  ),
                  style: GoogleFonts.inter(
                      fontSize: 14.sp, fontWeight: FontWeight.w400),
                )
              ],
            ),
            10.verticalSpace,
            Row(
              children: [
                Text(
                  AppHelpers.getTranslation(TrKeys.totalPrice),
                  style: GoogleFonts.inter(
                      fontSize: 14.sp, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  AppHelpers.numberFormat(
                    widget.orderData?.totalPrice ?? 0,
                  ),
                  style: GoogleFonts.inter(
                      fontSize: 14.sp, fontWeight: FontWeight.w400),
                )
              ],
            ),
            10.verticalSpace,
            Row(
              children: List.generate(
                  20,
                  (index) => Expanded(
                        child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 4.r),
                            height: 2,
                            color: AppStyle.iconButtonBack),
                      )),
            ),
            26.verticalSpace,
            Text(
              AppHelpers.getTranslation(TrKeys.thankYou).toUpperCase(),
              style: GoogleFonts.inter(
                  fontSize: 16.sp, fontWeight: FontWeight.w500),
            ),
            24.verticalSpace,
            LoginButton(
                title: AppHelpers.getTranslation(TrKeys.print),
                onPressed: () async {
                  if (context.mounted) {
                    AppHelpers.showAlertDialog(
                        context: context,
                        child: PrintPage(orderData: widget.orderData));
                  }
                })
          ],
        ),
      ),
    );
  }
}
