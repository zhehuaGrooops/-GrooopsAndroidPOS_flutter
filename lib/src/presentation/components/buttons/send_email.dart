// ignore_for_file: deprecated_member_use

import 'package:admin_desktop/src/models/data/order_body_data.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/constants.dart';
import '../../../core/utils/app_helpers.dart';
import '../login_button.dart';
import '../../../core/di/injection.dart';
import '../../../core/handlers/handlers.dart';

final connectivityProvider =
    StreamProvider<List<ConnectivityResult>>((ref) async* {
  yield await Connectivity().checkConnectivity();
  yield* Connectivity().onConnectivityChanged;
});

class InvoiceEmail extends ConsumerStatefulWidget {
  final OrderBodyData? orderData;

  const InvoiceEmail({super.key, required this.orderData});

  @override
  ConsumerState<InvoiceEmail> createState() => _InvoiceEmailState();
}

class _InvoiceEmailState extends ConsumerState<InvoiceEmail> {
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
    final connectivityAsync = ref.watch(connectivityProvider);

    return connectivityAsync.when(
      data: (results) {
        final hasNetwork = results.any((r) =>
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.ethernet);

        if (!hasNetwork) {
          return const SizedBox.shrink();
        }
        return LoginButton(
          title: AppHelpers.getTranslation(TrKeys.sendEmail),
          isLoading: _loading,
          isActive: widget.orderData != null && !_loading,
          onPressed: (widget.orderData != null && !_loading)
              ? () async {
                  await _promptAndSendEmail();
                }
              : null,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
