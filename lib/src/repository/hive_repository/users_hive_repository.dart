import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/handlers/handlers.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:admin_desktop/src/models/response/users_paginate_response.dart';
import 'package:admin_desktop/src/models/response/single_user_response.dart';
import 'package:admin_desktop/src/models/response/profile_response.dart';
import 'package:admin_desktop/src/models/response/edit_profile.dart';
import 'package:admin_desktop/src/models/data/customer_model.dart';
import 'package:admin_desktop/src/models/data/user_data.dart';
import 'package:hive/hive.dart';

import '../../core/db/hive_service.dart';
import '../users_repository.dart';

class UsersHiveRepository extends UsersRepository {
  Future<Box> _box() => HiveService.openBox(HiveBoxes.users);

  Future<ApiResult<UsersPaginateResponse>> saveUsers(
      List<UserData> users) async {
    try {
      final box = await _box();
      final profile = box.get('profile');
      await box.clear();
      if (profile != null) {
        await box.put('profile', profile);
      }
      for (final user in users) {
        if (user.id != null) {
          await box.put(user.id, user.toJson());
        } else if (user.uuid != null) {
          await box.put(user.uuid, user.toJson());
        } else {
          await box.add(user.toJson());
        }
      }
      return ApiResult.success(data: UsersPaginateResponse(users: users));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<UsersPaginateResponse>> searchUsers(
      {String? query, String? role, String? inviteStatus, int? page}) async {
    try {
      final box = await _box();
      final items = box.values.whereType<Map>().toList();
      final filtered = items.where((e) {
        final first = (e['firstname'] ?? '').toString();
        final last = (e['lastname'] ?? '').toString();
        final name = ('${first.trim()} ${last.trim()}').trim().toLowerCase();
        final q = query?.toLowerCase() ?? '';
        return q.isEmpty || name.contains(q);
      }).toList();
      final users = filtered
          .map((e) => UserData.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return ApiResult.success(data: UsersPaginateResponse(users: users));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<UsersPaginateResponse>> searchDeliveryman(
      String? query) async {
    return searchUsers(query: query);
  }

  @override
  Future<ApiResult<SingleUserResponse>> getUserDetails(String uuid) async {
    try {
      final box = await _box();
      for (final v in box.values) {
        if (v is Map && v['uuid'] == uuid) {
          return ApiResult.success(
              data: SingleUserResponse(
                  data: UserData.fromJson(Map<String, dynamic>.from(v))));
        }
      }
      return ApiResult.failure(error: 'Not found');
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<ProfileResponse>> getProfileDetails() async {
    try {
      final box = await _box();
      final map = box.get('profile') as Map?;
      final data = map != null
          ? ProfileResponse.fromJson(Map<String, dynamic>.from(map))
          : ProfileResponse();
      return ApiResult.success(data: data);
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<bool>> checkDriverZone(LatLng location, int? shopId) async {
    return const ApiResult.success(data: true);
  }

  @override
  Future<ApiResult> checkCoupon(
      {required String coupon, required int shopId}) async {
    return const ApiResult.success(data: null);
  }

  @override
  Future<ApiResult<ProfileResponse>> editProfile(
      {required EditProfile? user}) async {
    try {
      final box = await _box();
      await box.put('profile', user?.toJson() ?? {});
      return ApiResult.success(data: ProfileResponse());
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<ProfileResponse>> updateProfileImage(
      {required String firstName, required String imageUrl}) async {
    try {
      final box = await _box();
      final map = Map<String, dynamic>.from((box.get('profile') as Map?) ?? {});
      map['firstname'] = firstName;
      map['img'] = imageUrl;
      await box.put('profile', map);
      return ApiResult.success(data: ProfileResponse());
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<ProfileResponse>> updatePassword(
      {required String password, required String passwordConfirmation}) async {
    try {
      final box = await _box();
      final map = Map<String, dynamic>.from((box.get('profile') as Map?) ?? {});
      map['password_updated_at'] = DateTime.now().toIso8601String();
      await box.put('profile', map);
      return ApiResult.success(data: ProfileResponse());
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<UsersPaginateResponse>> getUsers({int? page}) async {
    try {
      final box = await _box();
      final users = box.values
          .whereType<Map>()
          .map((e) => UserData.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return ApiResult.success(data: UsersPaginateResponse(users: users));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<ProfileResponse>> createUser(
      {required CustomerModel query}) async {
    try {
      final box = await _box();
      await box.add(query.toJson());
      return ApiResult.success(data: ProfileResponse());
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }
}
