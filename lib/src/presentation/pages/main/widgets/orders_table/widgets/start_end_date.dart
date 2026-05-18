import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:admin_desktop/src/core/utils/utils.dart';
import 'package:admin_desktop/src/presentation/components/buttons/animation_button_effect.dart';
import 'package:admin_desktop/src/presentation/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class StartEndDate extends StatelessWidget {
  final DateTime? start;
  final DateTime? end;
  final Widget? filterScreen;

  const StartEndDate({super.key, this.start, this.end, this.filterScreen});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        AppHelpers.showAlertDialog(
            context: context,
            child: SizedBox(
                width: MediaQuery.of(context).size.width / 3,
                child: filterScreen));
      },
      child: AnimationButtonEffect(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.r, horizontal: 16.r),
          decoration: BoxDecoration(
            color: AppStyle.white,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: AppStyle.unselectedBottomBarBack,
              width: 1.r,
            ),
          ),
          child: Row(
            children: [
              const Icon(FlutterRemix.calendar_check_line),
              16.horizontalSpace,
              Text(
                start == null
                    ? AppHelpers.getTranslation(TrKeys.startEnd)
                    : "${DateFormat("MMM d,yyyy").format(start ?? DateTime.now())} - ${DateFormat("MMM d,yyyy").format(end ?? DateTime.now())}",
                style: GoogleFonts.inter(fontSize: 14.sp),
              )
            ],
          ),
        ),
      ),
    );
  }
}
