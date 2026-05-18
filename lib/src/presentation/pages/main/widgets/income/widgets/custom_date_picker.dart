import 'package:admin_desktop/src/presentation/theme/app_style.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomDatePicker extends StatefulWidget {
  final List<DateTime?> range;
  final ValueChanged<List<DateTime?>> onChange;

  const CustomDatePicker(
      {super.key, required this.range, required this.onChange});

  @override
  State<CustomDatePicker> createState() => _CustomDatePickerState();
}

class _CustomDatePickerState extends State<CustomDatePicker> {
  final config = CalendarDatePicker2Config(
    calendarType: CalendarDatePicker2Type.range,
    selectedDayHighlightColor: AppStyle.primary,
    weekdayLabelTextStyle: GoogleFonts.inter(
        fontSize: 14.sp, letterSpacing: -0.3, color: AppStyle.black),
    controlsTextStyle: GoogleFonts.inter(
        fontSize: 14.sp, letterSpacing: -0.3, color: AppStyle.black),
    dayTextStyle: GoogleFonts.inter(
        fontSize: 14.sp, letterSpacing: -0.3, color: AppStyle.black),
    disabledDayTextStyle: GoogleFonts.inter(
        fontSize: 14.sp, letterSpacing: -0.3, color: AppStyle.icon),
    dayBorderRadius: BorderRadius.circular(10.r),
  );

  @override
  Widget build(BuildContext context) {
    return CalendarDatePicker2(
        key: UniqueKey(),
        config: config,
        value: widget.range,
        onValueChanged: widget.onChange);
  }
}
