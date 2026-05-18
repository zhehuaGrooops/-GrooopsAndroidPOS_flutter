import 'package:admin_desktop/src/core/routes/app_router.dart';
import 'package:admin_desktop/src/models/models.dart';
import 'package:admin_desktop/src/models/response/edit_profile.dart';
import 'package:admin_desktop/src/presentation/pages/main/riverpod/provider/main_provider.dart';
import 'package:admin_desktop/src/presentation/theme/theme.dart';
import 'package:admin_desktop/src/repository/impl/users_repository_impl.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../../../../core/constants/constants.dart';
import '../../../../../../../../core/utils/app_helpers.dart';
import '../../../../../../../../core/utils/local_storage.dart';
import '../../../../../../../../repository/gallery.dart';
import '../../../../../../../components/dialogs/successfull_dialog.dart';
import '../state/edit_profile_state.dart';

class EditProfileNotifier extends StateNotifier<EditProfileState> {
  final GalleryRepositoryFacade _galleryRepository;
  EditProfileNotifier(this._galleryRepository)
      : super(const EditProfileState());

  Future<void> getPhoto() async {
    final ImagePicker picker = ImagePicker();
    XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Image Cropper',
            toolbarColor: AppStyle.white,
            toolbarWidgetColor: AppStyle.black,
            initAspectRatio: CropAspectRatioPreset.original,
          ),
          IOSUiSettings(title: 'Image Cropper', minimumAspectRatio: 1),
        ],
      );
      state = state.copyWith(imagePath: croppedFile?.path ?? "");
    }
  }

  changeIndex(int index) {
    state = state.copyWith(selectIndex: index);
  }

  void setShowPassword(bool show) {
    state = state.copyWith(showPassword: show);
  }

  void setShowOldPassword(bool show) {
    state = state.copyWith(showOldPassword: show);
  }

  void setShowPersonalPincode(bool show) {
    state = state.copyWith(showPincode: show);
  }

  void setGender(String gender) {
    state = state.copyWith(gender: gender);
  }

  void setBirth(String birth) {
    state = state.copyWith(birth: birth);
  }

  Future<void> editProfile(BuildContext context, UserData user) async {
    state = state.copyWith(isLoading: true, isSuccess: false);
    if (state.imagePath.isNotEmpty) {
      // ignore: use_build_context_synchronously
      await updateProfileImage(context, state.imagePath);
    }

    final usersRepository = UsersRepositoryImpl();

    final response = await usersRepository.editProfile(
        user: EditProfile(
      firstname: state.firstName.isEmpty ? user.firstname : state.firstName,
      lastname: state.lastName.isEmpty ? user.lastname : state.lastName,
      birthday: state.birth.isEmpty ? user.birthday : state.birth,
      phone: state.phone.isEmpty ? user.phone : state.phone,
      images: state.url.isEmpty ? user.img ?? "" : state.url,
      gender: state.gender,
    ));
    response.when(
      success: (data) {
        final currentUser = LocalStorage.getUser();
        final mergedUser = currentUser != null && data.data != null
            ? currentUser.copyWith(
                firstname: data.data?.firstname,
                lastname: data.data?.lastname,
                email: data.data?.email,
                phone: data.data?.phone,
                birthday: data.data?.birthday,
                gender: data.data?.gender,
                img: data.data?.img,
                addresses: data.data?.addresses,
                wallet: data.data?.wallet,
                role: data.data?.role,
                shop: data.data?.shop,
                invite: data.data?.invite,
              )
            : data.data;

        LocalStorage.setUser(mergedUser);

        state = state.copyWith(
          userData: mergedUser,
          isLoading: false,
          isSuccess: true,
        );

        showDialog(
            context: context,
            builder: (_) => Dialog(child: Consumer(
                  builder:
                      (BuildContext context, WidgetRef ref, Widget? child) {
                    return SuccessfullDialog(
                        title: AppHelpers.getTranslation(TrKeys.profileEdited),
                        content: AppHelpers.getTranslation(TrKeys.goToHome),
                        onPressed: () {
                          Navigator.pop(context);
                          ref.read(mainProvider.notifier).changeIndex(0);
                        });
                  },
                )));
      },
      failure: (failure, status) {
        state = state.copyWith(isLoading: false);
        AppHelpers.showSnackBar(
          context,
          AppHelpers.getTranslation(failure.toString()),
        );
      },
    );
  }

  Future<void> updatePassword(BuildContext context,
      {required String password, required String confirmPassword}) async {
    state = state.copyWith(isLoading: true, isSuccess: false);
    final usersRepository = UsersRepositoryImpl();
    final response = await usersRepository.updatePassword(
      password: password,
      passwordConfirmation: confirmPassword,
    );
    response.when(
      success: (data) async {
        state = state.copyWith(isLoading: false, isSuccess: true);
        context.replaceRoute(const MainRoute());
      },
      failure: (failure, status) {
        state = state.copyWith(isLoading: false);
        AppHelpers.showSnackBar(
          context,
          AppHelpers.getTranslation(failure.toString()),
        );
      },
    );
  }

  Future<void> updateProfileImage(BuildContext context, String path) async {
    String? url;
    final imageResponse =
        await _galleryRepository.uploadImage(path, UploadType.users);
    imageResponse.when(
      success: (data) {
        url = data.imageData?.title;
        state = state.copyWith(url: url ?? "");
      },
      failure: (failure, status) {
        state = state.copyWith(isLoading: false);
        debugPrint('==> upload profile image failure: $failure');
        AppHelpers.showSnackBar(
          context,
          AppHelpers.getTranslation(failure.toString()),
        );
      },
    );
  }
}
