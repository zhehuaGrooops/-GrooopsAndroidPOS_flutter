import 'dart:convert';

import 'package:admin_desktop/src/core/di/dependency_manager.dart';
import 'package:admin_desktop/src/models/data/customer_model.dart';
import 'package:admin_desktop/src/models/response/edit_profile.dart';
import 'package:admin_desktop/src/models/response/profile_response.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/handlers/handlers.dart';
import '../../core/utils/utils.dart';
import '../../models/models.dart';
import '../repository.dart';

class UsersRepositoryImpl extends UsersRepository {
  @override
  Future<ApiResult<UsersPaginateResponse>> searchUsers({
    String? query,
    String? role,
    String? inviteStatus,
    int? page,
  }) async {
    final data = {
      if (query != null) 'search': query,
      'perPage': 14,
      if (page != null) 'page': page,
      'sort': 'desc',
      'column': 'created_at',
      if (inviteStatus != null) 'invite_status': inviteStatus,
      if (role != null) 'role': role,
    };
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get(
        role != null
            ? '/api/v1/dashboard/seller/shop/users/paginate'
            : '/api/v1/dashboard/seller/users/paginate',
        queryParameters: data,
      );
      return ApiResult.success(
        data: UsersPaginateResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> search users failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'UsersRepositoryImpl.searchUsers',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<UsersPaginateResponse>> searchDeliveryman(
      String? query) async {
    final data = {
      if (query != null) 'search': query,
      'lang': LocalStorage.getLanguage()?.locale ?? 'en',
    };
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/shop/users/role/deliveryman',
        queryParameters: data,
      );
      return ApiResult.success(
        data: UsersPaginateResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> search users failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'UsersRepositoryImpl.searchDeliveryman',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<SingleUserResponse>> getUserDetails(String uuid) async {
    final data = {'lang': LocalStorage.getLanguage()?.locale ?? 'en'};
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/users/$uuid',
        queryParameters: data,
      );
      return ApiResult.success(
        data: SingleUserResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get user details failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'UsersRepositoryImpl.getUserDetails',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<ProfileResponse>> getProfileDetails() async {
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/user/profile/show',
      );
      LocalStorage.setUser(ProfileResponse.fromJson(response.data).data);
      return ApiResult.success(
        data: ProfileResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'UsersRepositoryImpl.getProfileDetails',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<bool>> checkDriverZone(LatLng location, int? shopId) async {
    try {
      final client = dioHttp.client(requireAuth: true);
      final data = <String, dynamic>{
        'address[latitude]': location.latitude,
        'address[longitude]': location.longitude,
      };

      final response = await client.get(
          '/api/v1/rest/shop/$shopId/delivery-zone/check/distance',
          queryParameters: data);

      return ApiResult.success(
        data: response.data["status"],
      );
    } catch (e, stackTrace) {
      debugPrint('==> get delivery zone failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'UsersRepositoryImpl.checkDriverZone',
      );
      return ApiResult.failure(
        error: AppHelpers.errorHandler(e),
      );
    }
  }

  @override
  Future<ApiResult> checkCoupon({
    required String coupon,
    required int shopId,
  }) async {
    final data = {
      'coupon': coupon,
      'shop_id': shopId,
    };
    try {
      final client = dioHttp.client(requireAuth: true);
      await client.post(
        '/api/v1/rest/coupons/check',
        data: data,
      );
      return const ApiResult.success(data: true);
    } catch (e, stackTrace) {
      debugPrint('==> check coupon failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'UsersRepositoryImpl.checkCoupon',
      );
      return ApiResult.failure(
        error: AppHelpers.errorHandler(e),
      );
    }
  }

  @override
  Future<ApiResult<ProfileResponse>> updatePassword(
      {required String password, required String passwordConfirmation}) async {
    final data = {
      'password': password,
      'password_confirmation': passwordConfirmation,
    };
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.post(
        '/api/v1/dashboard/user/profile/password/update',
        data: data,
      );
      return ApiResult.success(
        data: ProfileResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> update password failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'UsersRepositoryImpl.updatePassword',
      );
      return ApiResult.failure(
        error: AppHelpers.errorHandler(e),
      );
    }
  }

  @override
  Future<ApiResult<ProfileResponse>> updateProfileImage(
      {required String firstName, required String imageUrl}) async {
    final data = {
      'firstname': firstName,
      'images': [imageUrl],
    };
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.put(
        '/api/v1/dashboard/user/profile/update',
        data: data,
      );
      return ApiResult.success(
        data: ProfileResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> update profile image failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'UsersRepositoryImpl.updateProfileImage',
      );
      return ApiResult.failure(
        error: AppHelpers.errorHandler(e),
      );
    }
  }

  @override
  Future<ApiResult<ProfileResponse>> editProfile(
      {required EditProfile? user}) async {
    final data = user?.toJson();
    debugPrint('===> update general info data ${jsonEncode(data)}');
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.put(
        '/api/v1/dashboard/user/profile/update',
        data: data,
      );
      return ApiResult.success(
        data: ProfileResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> update profile details failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'UsersRepositoryImpl.editProfile',
      );
      return ApiResult.failure(
        error: AppHelpers.errorHandler(e),
      );
    }
  }

  @override
  Future<ApiResult<ProfileResponse>> createUser(
      {required CustomerModel query}) async {
    final data = query.toJson();
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.post(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/users',
        data: data,
      );
      return ApiResult.success(
        data: ProfileResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> create user failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'UsersRepositoryImpl.createUser',
      );
      return ApiResult.failure(
        error: AppHelpers.errorHandler(e),
      );
    }
  }

  @override
  Future<ApiResult<UsersPaginateResponse>> getUsers({int? page}) async {
    final data = {
      'perPage': 6,
    };
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get(
          '/api/v1/dashboard/${LocalStorage.getUser()?.role}/users/paginate',
          queryParameters: data);
      return ApiResult.success(
        data: UsersPaginateResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get users failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'UsersRepositoryImpl.getUsers',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }
}
