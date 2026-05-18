// ignore_for_file: deprecated_member_use

import 'package:admin_desktop/src/models/data/order_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/constants.dart';
import '../../../core/utils/app_helpers.dart';
import '../../theme/app_style.dart';
import 'animation_button_effect.dart';
import '../../../core/di/injection.dart';
import '../../../core/handlers/handlers.dart';

class InvoiceEmail extends StatefulWidget {
  final OrderData? orderData;

  const InvoiceEmail({super.key, required this.orderData});

  @override
  State<InvoiceEmail> createState() => _InvoiceEmailState();
}

class _InvoiceEmailState extends State<InvoiceEmail> {
  bool _loading = false;

  /// Prompt user for email before sending
  Future<void> _promptAndSendEmail() async {
    final emailController = TextEditingController(
      text: widget.orderData?.user?.email ?? "",
    );

    final email = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Send Receipt"),
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: "Insert Email Address Here",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(emailController.text.trim());
              },
              child: const Text("Send"),
            ),
          ],
        );
      },
    );

    if (email != null && email.isNotEmpty) {
      await _sendEmail(email);
    }
  }

  Future<void> _sendEmail(String email) async {
    if (widget.orderData == null) return;

    setState(() => _loading = true);

    try {
      final client = inject<HttpService>().client(requireAuth: true);

      final response = await client.post(
        '/api/v1/rest/orders/${widget.orderData?.id}/send-receipt',
        data: {"email": email},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.data["message"] ?? "Email sent successfully!",
              style: GoogleFonts.inter(fontSize: 14.sp),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to send receipt email",
              style: GoogleFonts.inter(fontSize: 14.sp),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimationButtonEffect(
      child: GestureDetector(
        onTap: _loading ? null : _promptAndSendEmail,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.r, horizontal: 18.r),
          decoration: BoxDecoration(
            color: AppStyle.invoiceColor,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              _loading
                  ? SizedBox(
                      width: 18.r,
                      height: 18.r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : SvgPicture.asset(
                      "assets/svg/email.svg",
                      color: AppStyle.white,
                      height: 18.r,
                      width: 18.r,
                    ),
              8.horizontalSpace,
              Text(
                AppHelpers.getTranslation(TrKeys.sendEmail),
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  letterSpacing: 0,
                  color: AppStyle.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
