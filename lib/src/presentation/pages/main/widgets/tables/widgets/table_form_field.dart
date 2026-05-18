import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../../core/utils/utils.dart';
import '../../../../../theme/theme.dart';

class TableFormField extends StatelessWidget {
  final String prefixSvg;
  final IconData? prefixIcon;
  final String? hintText;
  final bool readOnly;
  final String? Function(String?)? validator;
  final Function(String)? onChanged;
  final VoidCallback? onTap;
  final TextInputType? inputType;
  final TextEditingController? textEditingController;
  final List<TextInputFormatter>? inputFormatters;

  const TableFormField(
      {super.key,
      required this.prefixSvg,
      this.validator,
      this.onChanged,
      this.inputType,
      this.hintText,
      this.textEditingController,
      this.readOnly = false,
      this.inputFormatters,
      this.prefixIcon,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      onTap: onTap,
      inputFormatters: inputFormatters,
      controller: textEditingController,
      validator: validator,
      onChanged: onChanged,
      readOnly: readOnly,
      keyboardType: inputType,
      style: GoogleFonts.inter(
          color: AppStyle.black, fontWeight: FontWeight.w500, fontSize: 14.sp),
      decoration: InputDecoration(
        hintText: AppHelpers.getTranslation(hintText ?? ""),
        hintStyle: GoogleFonts.inter(
          color: AppStyle.hint,
          fontWeight: FontWeight.w500,
          fontSize: 13.sp,
        ),
        contentPadding: REdgeInsets.symmetric(vertical: 12, horizontal: 12),
        prefixIcon: Padding(
          padding: REdgeInsets.symmetric(vertical: 16),
          child: prefixIcon == null
              ? SvgPicture.asset(
                  prefixSvg,
                  width: 26.r,
                  color: AppStyle.black,
                )
              : Icon(
                  prefixIcon,
                  size: 26.r,
                  color: AppStyle.black,
                ),
        ),
        filled: true,
        fillColor: AppStyle.editProfileCircle,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.r),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.r),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.r),
            borderSide: BorderSide.none),
      ),
    );
  }
}
