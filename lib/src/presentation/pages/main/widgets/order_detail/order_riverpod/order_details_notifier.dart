import 'dart:async';

import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:admin_desktop/src/core/utils/app_helpers.dart';
import 'package:admin_desktop/src/models/data/order_data.dart';
import 'package:admin_desktop/src/models/models.dart';
import 'package:admin_desktop/src/repository/repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'order_details_state.dart';

class OrderDetailsNotifier extends StateNotifier<OrderDetailsState> {
  final OrdersRepository _ordersRepository;
  final UsersRepository _usersRepository;

  OrderDetailsNotifier(this._ordersRepository, this._usersRepository)
      : super(const OrderDetailsState());
  Timer? _searchUsersTimer;
  Future<void> updateOrderDetailStatus({
    required String status,
    required int? id,
    VoidCallback? success,
  }) async {
    state = state.copyWith(isUpdating: true);
    final response = await _ordersRepository.updateOrderDetailStatus(
      status: status,
      orderId: id,
    );
    response.when(
      success: (data) {
        state = state.copyWith(isUpdating: false);
        fetchOrderDetails(order: state.order);
        success?.call();
      },
      failure: (failure, code) {
        debugPrint('===> update order detail status fail $failure');
        state = state.copyWith(isUpdating: false);
      },
    );
  }

  void changeDetailStatus(String status) {
    state = state.copyWith(detailStatus: status);
  }

  Future<void> updateOrderStatus({
    required OrderStatus status,
    VoidCallback? success,
  }) async {
    state = state.copyWith(isUpdating: true);
    final response = await _ordersRepository.updateOrderStatus(
      status: status,
      orderId: state.order?.id,
    );
    response.when(
      success: (data) {
        state = state.copyWith(isUpdating: false);
        fetchOrderDetails(order: state.order);
        success?.call();
      },
      failure: (failure, status) {
        debugPrint('===> update order status fail $failure');
        state = state.copyWith(isUpdating: false);
      },
    );
  }

  void toggleOrderDetailChecked({required int index}) {
    List<OrderDetail>? orderDetails = state.order?.details;
    if (orderDetails == null || orderDetails.isEmpty) {
      return;
    }
    OrderDetail detail = orderDetails[index];
    final bool isChecked = detail.isChecked ?? false;
    detail = detail.copyWith(isChecked: !isChecked);
    orderDetails[index] = detail;
    final order = state.order?.copyWith(details: orderDetails);
    state = state.copyWith(order: order);
  }

  void changeStatus(String status) {
    state = state.copyWith(status: status);
  }

  Future<void> fetchOrderDetails({OrderData? order}) async {
    state = state.copyWith(isLoading: true, order: order);
    final response =
        await _ordersRepository.getOrderDetails(orderId: order?.id);
    response.when(
      success: (data) {
        state = state.copyWith(isLoading: false, order: data.data);
      },
      failure: (failure, status) {
        debugPrint('===> fetch order details fail $failure');
        state = state.copyWith(isLoading: false);
      },
    );
  }

  Future<void> fetchUsers({VoidCallback? checkYourNetwork}) async {
    state = state.copyWith(
      isUsersLoading: true,
      dropdownUsers: [],
      users: [],
    );
    final response = await _usersRepository
        .searchDeliveryman(state.usersQuery.isEmpty ? null : state.usersQuery);
    response.when(
      success: (data) async {
        final List<UserData> users = data.users ?? [];
        List<DropDownItemData> dropdownUsers = [];
        for (int i = 0; i < users.length; i++) {
          dropdownUsers.add(
            DropDownItemData(
              index: i,
              title: '${users[i].firstname} ${users[i].lastname ?? ""}',
            ),
          );
        }
        state = state.copyWith(
          isUsersLoading: false,
          users: users,
          dropdownUsers: dropdownUsers,
        );
      },
      failure: (failure, status) {
        state = state.copyWith(isUsersLoading: false);
        debugPrint('==> get users failure: $failure');
      },
    );
  }

  void setUsersQuery(BuildContext context, String query) {
    if (state.usersQuery == query) {
      return;
    }
    state = state.copyWith(usersQuery: query.trim());

    if (_searchUsersTimer?.isActive ?? false) {
      _searchUsersTimer?.cancel();
    }
    _searchUsersTimer = Timer(
      const Duration(milliseconds: 500),
      () {
        state = state.copyWith(users: [], dropdownUsers: []);
        fetchUsers(
          checkYourNetwork: () {
            AppHelpers.showSnackBar(
              context,
              AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection),
            );
          },
        );
      },
    );
  }

  void setSelectedUser(BuildContext context, int index) {
    final user = state.users[index];
    state = state.copyWith(
      selectedUser: user,
    );

    setUsersQuery(context, '');
  }

  Future<void> setDeliveryMan(BuildContext context) async {
    state = state.copyWith(isUpdating: true);
    final response = await _ordersRepository.setDeliverMan(
      orderId: state.order?.id ?? 0,
      deliverymanId: state.selectedUser?.id ?? 0,
    );
    response.when(
      success: (data) {
        fetchOrderDetails(order: state.order);
      },
      failure: (failure, status) {
        debugPrint('===> set deliveryman fail $failure');
        AppHelpers.showSnackBar(
          context,
          AppHelpers.getTranslation(TrKeys.somethingWentWrongWithTheServer),
        );
      },
    );
  }

  void removeSelectedUser() {
    state = state.copyWith(
      selectedUser: null,
    );
  }
}
