import 'dart:async';
import 'package:admin_desktop/src/models/data/customer_model.dart';
import 'package:admin_desktop/src/models/data/user_data.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/customers/riverpod/state/customer_state.dart';
import 'package:admin_desktop/src/repository/gallery.dart';
import 'package:admin_desktop/src/repository/repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../../core/constants/constants.dart';
import '../../../../../../../core/utils/app_helpers.dart';
import '../../../../../../components/dialogs/successfull_dialog.dart';
import '../../../../riverpod/provider/main_provider.dart';

class CustomerNotifier extends StateNotifier<CustomerState> {
  final UsersRepository _usersRepository;
  final GalleryRepositoryFacade _galleryRepository;
  int _page = 0;

  CustomerNotifier(this._usersRepository, this._galleryRepository)
      : super(const CustomerState());

  void setUser(UserData? user) {
    state = state.copyWith(selectUser: user);
  }

  void setImageFile(String? file) {
    state = state.copyWith(imageFile: file);
  }

  Future<void> fetchAllUsers({VoidCallback? checkYourNetwork}) async {
    if (_page == 0) {
      state = state.copyWith(isLoading: true, users: []);

      final response = await _usersRepository.getUsers(
        page: ++_page,
      );
      response.when(
        success: (data) {
          state = state.copyWith(
            users: data.users ?? [],
            isLoading: false,
          );
          if ((data.users?.length ?? 0) < 5) {
            state = state.copyWith(hasMore: false);
          }
        },
        failure: (failure, status) {
          state = state.copyWith(isLoading: false);
          debugPrint('==> get products failure: $failure');
        },
      );
    } else {
      state = state.copyWith(isMoreLoading: true);
      final response = await _usersRepository.getUsers(page: ++_page);
      response.when(
        success: (data) async {
          final List<UserData> newList = List.from(state.users);
          newList.addAll(data.users ?? []);
          state = state.copyWith(
            users: newList,
            isMoreLoading: false,
          );
          if ((data.users?.length ?? 0) < 5) {
            state = state.copyWith(hasMore: false);
          }
        },
        failure: (failure, status) {
          state = state.copyWith(isMoreLoading: false);
          debugPrint('==> get users  failure: $failure');
        },
      );
    }
  }

  Future<void> createCustomer(BuildContext context,
      {required String name,
      required String lastName,
      required String email,
      required String phone,
      String? createRole,
      String? password,
      Function(UserData?)? created,
      bool needAlert = true}) async {
    state = state.copyWith(createUserLoading: true);
    String? imageUrl;
    if (state.imageFile?.isNotEmpty ?? false) {
      final res = await _galleryRepository.uploadImage(
          state.imageFile!, UploadType.users);
      res.when(success: (success) {
        imageUrl = success.imageData?.title;
      }, failure: (failure, status) {
        debugPrint('==> upload service image fail: $failure');
        AppHelpers.showSnackBar(context, failure.toString());
      });
    }
    final response = await _usersRepository.createUser(
        query: CustomerModel(
            imageUrl: imageUrl,
            role: createRole ?? 'user',
            firstname: name,
            lastname: lastName,
            email: email,
            phone: int.tryParse(phone),
            password: password));
    response.when(
      success: (data) {
        _page = 0;
        fetchAllUsers();
        state = state.copyWith(user: data.data, createUserLoading: false);
        created?.call(data.data);
        if (needAlert) {
          showDialog(
              context: context,
              builder: (_) => Dialog(child: Consumer(
                    builder:
                        (BuildContext context, WidgetRef ref, Widget? child) {
                      return SuccessfullDialog(
                          title:
                              AppHelpers.getTranslation(TrKeys.customerAdded),
                          content: AppHelpers.getTranslation(TrKeys.goToHome),
                          onPressed: () {
                            Navigator.pop(context);
                            ref.read(mainProvider.notifier).changeIndex(0);
                          });
                    },
                  )));
        }
      },
      failure: (failure, status) {
        state = state.copyWith(createUserLoading: false);
        AppHelpers.showSnackBar(
          context,
          AppHelpers.getTranslation(failure.toString()),
        );
      },
    );
  }

  Future<void> searchUsers(BuildContext context, String text) async {
    if (state.query == text) {
      return;
    }
    state = state.copyWith(isLoading: true, query: text);
    final response = await _usersRepository.searchUsers(query: text.trim());
    response.when(
      success: (data) async {
        state = state.copyWith(isLoading: false, users: data.users ?? []);
      },
      failure: (failure, status) {
        state = state.copyWith(isLoading: false);
        AppHelpers.showSnackBar(context, failure);
      },
    );
  }
}
