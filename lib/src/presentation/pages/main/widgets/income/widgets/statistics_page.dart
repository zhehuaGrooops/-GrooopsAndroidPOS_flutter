import 'package:admin_desktop/src/core/utils/app_helpers.dart';
import 'package:admin_desktop/src/models/response/income_statistic_response.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../../../../../../core/constants/constants.dart';
import '../../../../../theme/app_style.dart';

class StatisticPage extends StatelessWidget {
  final IncomeStatisticResponse? statistic;
  const StatisticPage({super.key, required this.statistic});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 360.r,
        padding: EdgeInsets.symmetric(horizontal: 20.r, vertical: 30.r),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.r), color: AppStyle.white),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            AppHelpers.getTranslation(TrKeys.statistics),
            style:
                GoogleFonts.inter(fontSize: 22.sp, fontWeight: FontWeight.w600),
          ),
          24.verticalSpace,
          Row(
            children: [
              Container(
                height: 14.r,
                width: 14.r,
                decoration: const BoxDecoration(
                  color: AppStyle.blue,
                  shape: BoxShape.circle,
                ),
              ),
              6.horizontalSpace,
              Text(
                AppHelpers.getTranslation(TrKeys.accepted),
                style: GoogleFonts.inter(fontSize: 14.sp),
              ),
              24.horizontalSpace,
              Container(
                height: 14.r,
                width: 14.r,
                decoration: const BoxDecoration(
                  color: AppStyle.revenueColor,
                  shape: BoxShape.circle,
                ),
              ),
              6.horizontalSpace,
              Text(
                AppHelpers.getTranslation(TrKeys.ready),
                style: GoogleFonts.inter(fontSize: 14.sp),
              ),
              24.horizontalSpace,
              Container(
                height: 14.r,
                width: 14.r,
                decoration: const BoxDecoration(
                  color: AppStyle.black,
                  shape: BoxShape.circle,
                ),
              ),
              6.horizontalSpace,
              Text(
                AppHelpers.getTranslation(TrKeys.onAWay),
                style: GoogleFonts.inter(fontSize: 14.sp),
              ),
              24.horizontalSpace,
              Container(
                height: 14.r,
                width: 14.r,
                decoration: const BoxDecoration(
                  color: AppStyle.primary,
                  shape: BoxShape.circle,
                ),
              ),
              6.horizontalSpace,
              Text(
                AppHelpers.getTranslation(TrKeys.delivered),
                style: GoogleFonts.inter(fontSize: 14.sp),
              ),
              24.horizontalSpace,
              Container(
                height: 14.r,
                width: 14.r,
                decoration: const BoxDecoration(
                  color: AppStyle.red,
                  shape: BoxShape.circle,
                ),
              ),
              6.horizontalSpace,
              Text(
                AppHelpers.getTranslation(TrKeys.cancel),
                style: GoogleFonts.inter(fontSize: 14.sp),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Container(
                height: 100.r,
                width: 100.r,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppStyle.blue.withOpacity(0.2)),
                child: CircularPercentIndicator(
                  radius: 50.r,
                  lineWidth: 8.r,
                  percent: (statistic?.accepted?.percent?.floor() ?? 0) / 100,
                  center: Text("${statistic?.accepted?.percent?.floor()}%",
                      style: GoogleFonts.inter(color: AppStyle.black)),
                  progressColor: AppStyle.blue,
                  backgroundColor: AppStyle.transparent,
                  circularStrokeCap: CircularStrokeCap.round,
                  rotateLinearGradient: true,
                ),
              ),
              24.horizontalSpace,
              Container(
                height: 100.r,
                width: 100.r,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppStyle.revenueColor.withOpacity(0.2)),
                child: CircularPercentIndicator(
                  radius: 50.r,
                  lineWidth: 8.r,
                  percent: (statistic?.ready?.percent?.floor() ?? 0) / 100,
                  center: Text("${statistic?.ready?.percent?.floor()}%",
                      style: GoogleFonts.inter(color: AppStyle.black)),
                  progressColor: AppStyle.revenueColor,
                  backgroundColor: AppStyle.transparent,
                  circularStrokeCap: CircularStrokeCap.round,
                  rotateLinearGradient: true,
                ),
              ),
              24.horizontalSpace,
              Container(
                height: 100.r,
                width: 100.r,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppStyle.black.withOpacity(0.2)),
                child: CircularPercentIndicator(
                  radius: 50.r,
                  lineWidth: 8.r,
                  percent: (statistic?.onAWay?.percent?.floor() ?? 0) / 100,
                  center: Text("${statistic?.onAWay?.percent?.floor()}%",
                      style: GoogleFonts.inter(color: AppStyle.black)),
                  progressColor: AppStyle.black,
                  backgroundColor: AppStyle.transparent,
                  circularStrokeCap: CircularStrokeCap.round,
                  rotateLinearGradient: true,
                ),
              ),
              24.horizontalSpace,
              Container(
                height: 100.r,
                width: 100.r,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppStyle.primary.withOpacity(0.2)),
                child: CircularPercentIndicator(
                  radius: 50.r,
                  lineWidth: 8.r,
                  percent: (statistic?.delivered?.percent?.floor() ?? 0) / 100,
                  center: Text("${statistic?.delivered?.percent?.floor()}%",
                      style: GoogleFonts.inter(color: AppStyle.black)),
                  progressColor: AppStyle.primary,
                  backgroundColor: AppStyle.transparent,
                  circularStrokeCap: CircularStrokeCap.round,
                  rotateLinearGradient: true,
                ),
              ),
              24.horizontalSpace,
              Container(
                height: 100.r,
                width: 100.r,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppStyle.red.withOpacity(0.2)),
                child: CircularPercentIndicator(
                  radius: 50.r,
                  lineWidth: 8.r,
                  percent: (statistic?.canceled?.percent?.floor() ?? 0) / 100,
                  center: Text("${statistic?.canceled?.percent?.floor()}%",
                      style: GoogleFonts.inter(color: AppStyle.black)),
                  progressColor: AppStyle.red,
                  backgroundColor: AppStyle.transparent,
                  circularStrokeCap: CircularStrokeCap.round,
                  rotateLinearGradient: true,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            AppHelpers.getTranslation(TrKeys.everyLarge),
            style: GoogleFonts.inter(fontSize: 14.sp, color: AppStyle.icon),
          ),
          12.verticalSpace,
        ]),
      ),
    );
  }
}
