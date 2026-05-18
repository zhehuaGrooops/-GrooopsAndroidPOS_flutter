import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/utils/utils.dart';
import '../../../../../../core/di/dependency_manager.dart';
import '../../../../../../core/sync/sync_service.dart';
import '../../../../../../models/models.dart';
import '../../../../../../repository/repository.dart';
import '../state/login_state.dart';

class LoginNotifier extends StateNotifier<LoginState> {
  final AuthRepository _authRepository;
  final UsersRepository _usersRepository;
  final CurrenciesRepository _currenciesRepository;

  LoginNotifier(
      this._authRepository, this._currenciesRepository, this._usersRepository)
      : super(const LoginState());

  void setPassword(String text) {
    state = state.copyWith(
      password: text.trim(),
      isLoginError: false,
      isEmailNotValid: false,
      isPasswordNotValid: false,
    );
  }

  void setEmail(String text) {
    state = state.copyWith(
      email: text.trim(),
      isLoginError: false,
      isEmailNotValid: false,
      isPasswordNotValid: false,
    );
  }

  void setShowPassword(bool show) {
    state = state.copyWith(showPassword: show);
  }

  Future<void> login({
    VoidCallback? checkYourNetwork,
    VoidCallback? unAuthorised,
    VoidCallback? goToMain,
  }) async {
    // Connectivity check is preserved here to ensure the user has an internet connection
    // before attempting to authenticate with the server.
    final connected = await AppConnectivity.connectivity();
    if (connected) {
      if (!AppValidators.isValidEmail(state.email)) {
        state = state.copyWith(isEmailNotValid: true);
        return;
      }
      state = state.copyWith(isLoading: true);
      final response = await _authRepository.login(
        email: state.email,
        password: state.password,
      );
      response.when(
        success: (data) async {
          LocalStorage.setToken(data.data?.accessToken ?? '');
          LocalStorage.setUser(data.data?.user);
          state = state.copyWith(isCurrenciesLoading: true, isLoading: false);
          await SyncService().start();

          // Register terminal ID after successful login so it's persisted locally
          try {
            final termRes = await settingsRepository.getTerminalID();
            termRes.when(success: (id) {
              debugPrint('Terminal ID registered: $id');
            }, failure: (err, status) {
              debugPrint('Failed registering terminal ID: $err');
            });
          } catch (e) {
            debugPrint('Error while registering terminal ID: $e');
          }

          fetchCurrencies(
            checkYourNetworkConnection: checkYourNetwork,
            goToMain: goToMain,
          );

          final res = await _usersRepository.getProfileDetails();

          res.when(success: (s) {}, failure: (failure, status) {});

          if (Platform.isAndroid || Platform.isIOS) {
            String? fcmToken;
            try {
              fcmToken = await FirebaseMessaging.instance.getToken();
            } catch (e) {
              debugPrint('===> error with getting firebase token $e');
            }
            _authRepository.updateFirebaseToken(fcmToken);
          }
        },
        failure: (failure, status) {
          state = state.copyWith(isLoading: false, isLoginError: true);
          if (status == 401) {
            unAuthorised?.call();
          }
          debugPrint('==> login failure: $failure');
        },
      );
    } else {
      checkYourNetwork?.call();
    }
  }

  Future<void> fetchCurrencies({
    VoidCallback? checkYourNetworkConnection,
    VoidCallback? goToMain,
  }) async {
    // Connectivity check is preserved here during the login flow to ensure essential
    // application data (currencies) is synchronized from the server upon initial entry.
    final connected = await AppConnectivity.connectivity();
    if (connected) {
      state = state.copyWith(isCurrenciesLoading: true);
      final response = await _currenciesRepository.getCurrencies();
      response.when(
        success: (data) async {
          int defaultCurrencyIndex = 0;
          final List<CurrencyData> currencies = data.data ?? [];
          if (currencies.isEmpty) {
            state = state.copyWith(isCurrenciesLoading: false);
            goToMain?.call();
            return;
          }
          for (int i = 0; i < currencies.length; i++) {
            if (currencies[i].isDefault ?? false) {
              defaultCurrencyIndex = i;
              break;
            }
          }
          LocalStorage.setSelectedCurrency(currencies[defaultCurrencyIndex]);
          state = state.copyWith(isCurrenciesLoading: false);
          goToMain?.call();
        },
        failure: (failure, status) async {
          state = state.copyWith(isCurrenciesLoading: false);
          goToMain?.call();
          debugPrint('==> get currency failure: $failure');
        },
      );
    } else {
      checkYourNetworkConnection?.call();
      goToMain?.call();
    }
  }
}
