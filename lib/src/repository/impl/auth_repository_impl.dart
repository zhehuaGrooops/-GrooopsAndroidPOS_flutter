import 'package:admin_desktop/src/core/utils/app_helpers.dart';
import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/handlers/handlers.dart';
import '../../models/models.dart';
import '../repository.dart';

class AuthRepositoryImpl extends AuthRepository {
  @override
  Future<ApiResult<LoginResponse>> login({
    required String email,
    required String password,
  }) async {
    final data = {'email': email, 'password': password};
    try {
      final client = inject<HttpService>().client(requireAuth: false);
      final response = await client.post(
        '/api/v1/auth/login',
        queryParameters: data,
      );
      return ApiResult.success(
        data: LoginResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> login failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'AuthRepositoryImpl.login',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<void>> updateFirebaseToken(String? token) async {
    final data = {if (token != null) 'firebase_token': token};
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      await client.post(
        '/api/v1/dashboard/user/profile/firebase/token/update',
        data: data,
      );
      return const ApiResult.success(data: null);
    } catch (e, stackTrace) {
      debugPrint('==> update firebase token failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'AuthRepositoryImpl.updateFirebaseToken',
      );
      return ApiResult.failure(
        error: AppHelpers.errorHandler(e),
      );
    }
  }
}
