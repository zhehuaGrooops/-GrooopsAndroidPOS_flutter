import 'package:admin_desktop/src/core/utils/app_validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../core/constants/constants.dart';
import '../../../../../../core/utils/app_helpers.dart';
import '../../../../../components/components.dart';
import 'package:admin_desktop/src/presentation/theme/theme.dart';
import '../riverpod/provider/customer_provider.dart';
import 'custom_button.dart';

class AddCustomerDialog extends ConsumerStatefulWidget {
  final bool needAlert;

  const AddCustomerDialog({super.key, this.needAlert = true});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _AddCustomDialogState();
}

class _AddCustomDialogState extends ConsumerState<AddCustomerDialog> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late TextEditingController firstName;
  late TextEditingController lastName;
  late TextEditingController email;
  late TextEditingController phone;
  late TextEditingController newPassword;
  late TextEditingController confirmPassword;

  @override
  void initState() {
    firstName = TextEditingController();
    lastName = TextEditingController();
    email = TextEditingController();
    newPassword = TextEditingController();
    confirmPassword = TextEditingController();
    phone = TextEditingController();

    super.initState();
  }

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    email.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
    phone.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(customerProvider.notifier);
    final state = ref.watch(customerProvider);
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppHelpers.getTranslation(TrKeys.addCustomer),
            style: GoogleFonts.inter(
                fontSize: 22.sp,
                color: AppStyle.black,
                fontWeight: FontWeight.w600),
          ),
          IconButton(
              splashRadius: 28.r,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(FlutterRemix.close_fill))
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedBorderTextField(
                validator: (s) {
                  if (s?.isEmpty ?? true) {
                    return AppHelpers.getTranslation(TrKeys.enterName);
                  }
                  return null;
                },
                textController: firstName,
                border: AppStyle.transparent,
                color: AppStyle.editProfileCircle,
                label: '${AppHelpers.getTranslation(TrKeys.firstname)}*',
                style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    color: AppStyle.black,
                    fontWeight: FontWeight.w500),
              ),
              12.verticalSpace,
              OutlinedBorderTextField(
                  validator: (s) {
                    if (s?.isEmpty ?? true) {
                      return AppHelpers.getTranslation(TrKeys.enterLastName);
                    }
                    return null;
                  },
                  textController: lastName,
                  border: AppStyle.transparent,
                  style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      color: AppStyle.black,
                      fontWeight: FontWeight.w500),
                  color: AppStyle.editProfileCircle,
                  label: '${AppHelpers.getTranslation(TrKeys.lastname)}*'),
              12.verticalSpace,
              OutlinedBorderTextField(
                  validator: (s) {
                    if (s?.isEmpty ?? true) {
                      return AppHelpers.getTranslation(TrKeys.enterPhone);
                    }
                    return null;
                  },
                  textController: phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  border: AppStyle.transparent,
                  style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      color: AppStyle.black,
                      fontWeight: FontWeight.w500),
                  color: AppStyle.editProfileCircle,
                  label: '${AppHelpers.getTranslation(TrKeys.phone)}*'),
              12.verticalSpace,
              OutlinedBorderTextField(
                  validator: (s) {
                    if (s?.isEmpty ?? true) {
                      return AppHelpers.getTranslation(TrKeys.enterEmail);
                    }
                    if (AppValidators.isValidEmail(s ?? "")) {
                      return null;
                    }
                    return AppHelpers.getTranslation(TrKeys.emailIsNotValid);
                  },
                  textController: email,
                  border: AppStyle.transparent,
                  style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      color: AppStyle.black,
                      fontWeight: FontWeight.w500),
                  color: AppStyle.editProfileCircle,
                  label: '${AppHelpers.getTranslation(TrKeys.email)}*'),
              48.verticalSpace,
              Row(
                children: [
                  SizedBox(
                    height: 40.r,
                    width: 148.r,
                    child: LoginButton(
                        isLoading: state.createUserLoading,
                        title: AppHelpers.getTranslation(TrKeys.save),
                        onPressed: () {
                          if (formKey.currentState?.validate() ?? false) {
                            notifier.createCustomer(context,
                                email: email.text,
                                needAlert: widget.needAlert,
                                lastName: lastName.text,
                                name: firstName.text,
                                phone: phone.text, created: (w) {
                              Navigator.pop(context);
                            });
                          }
                        }),
                  ),
                  21.r.horizontalSpace,
                  CustomButton(
                    onTap: () => Navigator.pop(context),
                    background: AppStyle.transparent,
                    title: AppHelpers.getTranslation(TrKeys.cancel),
                    textColor: AppStyle.black,
                    border: AppStyle.icon,
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
