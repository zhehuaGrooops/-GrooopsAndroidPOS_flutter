import 'package:admin_desktop/src/models/models.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/profile/edit_profile/riverpod/provider/edit_profile_provider.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/profile/edit_profile/widgets/custom_date_textform.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/profile/edit_profile/widgets/label_and_textform.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../core/constants/constants.dart';
import '../../../../../../core/utils/app_helpers.dart';
import '../../../../../../core/utils/local_storage.dart';
import '../../../../../components/buttons/circle_choosing_button.dart';
import '../../../../../components/components.dart';
import '../../../../../components/custom_edit_profile_widget.dart';
import '../../../../../theme/app_style.dart';
import 'package:intl/intl.dart' as intl;

final connectivityProvider =
    StreamProvider<List<ConnectivityResult>>((ref) async* {
  yield await Connectivity().checkConnectivity();
  yield* Connectivity().onConnectivityChanged;
});

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late TextEditingController firstName;
  late TextEditingController lastName;
  late TextEditingController email;
  late TextEditingController confirmPassword;
  late TextEditingController phoneNumber;
  late TextEditingController newPassword;
  late TextEditingController dateOfBirth;
  late TextEditingController personalPinCode;

  @override
  void initState() {
    firstName = TextEditingController();
    lastName = TextEditingController();
    email = TextEditingController();
    phoneNumber = TextEditingController();
    dateOfBirth = TextEditingController();
    confirmPassword = TextEditingController();
    newPassword = TextEditingController();
    personalPinCode = TextEditingController();
    getInfo();

    super.initState();
  }

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    email.dispose();
    phoneNumber.dispose();
    dateOfBirth.dispose();
    confirmPassword.dispose();
    newPassword.dispose();
    personalPinCode.dispose();
    super.dispose();
  }

  getInfo() {
    firstName.text = LocalStorage.getUser()?.firstname ?? '';
    lastName.text = LocalStorage.getUser()?.lastname ?? '';
    dateOfBirth.text = LocalStorage.getUser()?.birthday ?? '';
    firstName.text = LocalStorage.getUser()?.firstname ?? '';
    phoneNumber.text = LocalStorage.getUser()?.phone ?? '';
    email.text = LocalStorage.getUser()?.email ?? '';
    dateOfBirth.text = intl.DateFormat("yyy-MM-dd").format(
        DateTime.tryParse(LocalStorage.getUser()?.birthday ?? '')?.toLocal() ??
            DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(editProfileProvider.notifier)
          .setGender(LocalStorage.getUser()?.gender ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(editProfileProvider.notifier);
    final state = ref.watch(editProfileProvider);
    final connectivityAsync = ref.watch(connectivityProvider);
    final isOnline = connectivityAsync.maybeWhen(
      data: (results) => results.any((r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet),
      orElse: () => true,
    );
    return AbsorbPointer(
      absorbing: !isOnline,
      child: Opacity(
        opacity: isOnline ? 1.0 : 0.5,
        child: Padding(
          padding: REdgeInsets.only(left: 16, top: 24, bottom: 16, right: 16),
          child: Container(
            decoration: const BoxDecoration(
                color: AppStyle.white,
                borderRadius: BorderRadius.all(Radius.circular(10))),
            child: Padding(
              padding: EdgeInsets.only(left: 16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  24.verticalSpace,
                  Row(
                    children: [
                      CustomEditWidget(
                          image: state.url,
                          imagePath: state.imagePath,
                          isEmptyorNot:
                              (LocalStorage.getUser()?.img?.isNotEmpty ??
                                      false) &&
                                  state.imagePath.isEmpty,
                          isEmptyorNot2: state.imagePath.isNotEmpty,
                          localStoreImage: LocalStorage.getUser()?.img ?? "",
                          onthisTap: () {
                            notifier.getPhoto();
                          }),
                      Padding(
                        padding: REdgeInsets.only(left: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${LocalStorage.getUser()?.firstname} ${LocalStorage.getUser()?.lastname?.substring(0, 1).toUpperCase()}.',
                              style: GoogleFonts.inter(
                                  fontSize: 24.sp,
                                  color: AppStyle.black,
                                  fontWeight: FontWeight.bold),
                            ),
                            8.verticalSpace,
                            Text(
                              '${LocalStorage.getUser()?.role}',
                              style: GoogleFonts.inter(
                                  fontSize: 18.sp,
                                  color: AppStyle.icon,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  42.verticalSpace,
                  Row(
                    children: [
                      for (int index = 0; index < 2; index++)
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                ref
                                    .read(editProfileProvider.notifier)
                                    .changeIndex(index);
                                notifier.setGender(
                                    index == 0 ? TrKeys.male : TrKeys.female);
                              },
                              child: CircleChoosingButton(
                                isActive: state.selectIndex == index,
                              ),
                            ),
                            12.horizontalSpace,
                            Padding(
                              padding: REdgeInsets.only(right: 32),
                              child: Text(
                                index == 0
                                    ? AppHelpers.getTranslation(TrKeys.male)
                                    : AppHelpers.getTranslation(TrKeys.female),
                                style: GoogleFonts.inter(
                                    fontSize: 15.sp,
                                    color: AppStyle.black,
                                    fontWeight: FontWeight.w500),
                              ),
                            )
                          ],
                        )
                    ],
                  ),
                  18.verticalSpace,
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: REdgeInsets.only(right: 80),
                          child: CustomColumnWidget(
                            controller: firstName,
                            trName: AppHelpers.getTranslation(TrKeys.firstname),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: REdgeInsets.only(right: 16),
                          child: CustomColumnWidget(
                            controller: lastName,
                            trName: AppHelpers.getTranslation(TrKeys.lastname),
                          ),
                        ),
                      )
                    ],
                  ),
                  24.verticalSpace,
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: REdgeInsets.only(right: 80),
                          child: CustomColumnWidget(
                            inputType: TextInputType.emailAddress,
                            controller: email,
                            trName: AppHelpers.getTranslation(TrKeys.email),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: REdgeInsets.only(right: 16),
                          child: CustomColumnWidget(
                            trName:
                                AppHelpers.getTranslation(TrKeys.newPassword),
                            controller: confirmPassword,
                            obscure: state.showOldPassword,
                            suffixIcon: GestureDetector(
                              child: Icon(
                                state.showOldPassword
                                    ? FlutterRemix.eye_line
                                    : FlutterRemix.eye_close_line,
                                color: AppStyle.black,
                                size: 20.r,
                              ),
                              onTap: () => notifier
                                  .setShowOldPassword(!state.showOldPassword),
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                  24.verticalSpace,
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: REdgeInsets.only(right: 80),
                          child: CustomColumnWidget(
                            inputType: TextInputType.phone,
                            controller: phoneNumber,
                            trName: AppHelpers.getTranslation(TrKeys.phone),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: REdgeInsets.only(right: 16),
                          child: CustomColumnWidget(
                            trName: AppHelpers.getTranslation(
                                TrKeys.confirmNewPassword),
                            controller: newPassword,
                            obscure: state.showPassword,
                            suffixIcon: IconButton(
                              splashRadius: 25.r,
                              icon: Icon(
                                state.showPassword
                                    ? FlutterRemix.eye_line
                                    : FlutterRemix.eye_close_line,
                                color: AppStyle.black,
                                size: 20.r,
                              ),
                              onPressed: () =>
                                  notifier.setShowPassword(!state.showPassword),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  24.verticalSpace,
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: REdgeInsets.only(right: 80),
                          child: CustomDateFormField(
                            controller: dateOfBirth,
                            text: AppHelpers.getTranslation(TrKeys.dateOfBirth),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: REdgeInsets.only(right: 16),
                          child: CustomColumnWidget(
                            maxLength: 4,
                            trName: AppHelpers.getTranslation(
                                TrKeys.personalPincode),
                            controller: personalPinCode,
                            inputType: TextInputType.number,
                            obscure: state.showPincode,
                            suffixIcon: IconButton(
                              splashRadius: 25.r,
                              icon: Icon(
                                state.showPincode
                                    ? FlutterRemix.eye_line
                                    : FlutterRemix.eye_close_line,
                                color: AppStyle.black,
                                size: 20.r,
                              ),
                              onPressed: () => notifier
                                  .setShowPersonalPincode(!state.showPincode),
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 250.r,
                    child: LoginButton(
                        isLoading: state.isLoading,
                        isActive: isOnline,
                        title: AppHelpers.getTranslation(TrKeys.save),
                        onPressed: isOnline
                            ? () {
                                notifier.editProfile(
                                    context,
                                    UserData(
                                      birthday: dateOfBirth.text,
                                      img: state.imagePath,
                                      firstname: firstName.text,
                                      lastname: lastName.text,
                                      email: email.text,
                                      phone: phoneNumber.text,
                                    ));
                                if (newPassword.text.isNotEmpty &&
                                    confirmPassword.text.isNotEmpty) {
                                  notifier.updatePassword(context,
                                      password: confirmPassword.text,
                                      confirmPassword: newPassword.text);
                                }
                                if (personalPinCode.text.isNotEmpty &&
                                    personalPinCode.text.length == 4) {
                                  LocalStorage.setPinCode(personalPinCode.text);
                                }
                              }
                            : null),
                  ),
                  24.verticalSpace,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
