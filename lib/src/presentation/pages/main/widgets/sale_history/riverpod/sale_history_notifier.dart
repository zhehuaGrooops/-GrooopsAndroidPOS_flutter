import 'dart:async';

import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/db/hive_service.dart';
import 'package:admin_desktop/src/models/response/sale_history_response.dart';
import 'package:admin_desktop/src/repository/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sale_history_state.dart';

class SaleHistoryNotifier extends StateNotifier<SaleHistoryState> {
  final SettingsRepository _settingsRepository;
  int driverPage = 0;
  int salePage = 0;
  int historyPage = 0;
  StreamSubscription? _subscription;
  Timer? _debounce;

  SaleHistoryNotifier(this._settingsRepository)
      : super(const SaleHistoryState()) {
    _initHiveListener();
  }

  void _initHiveListener() async {
    final box = await HiveService.openBox(HiveBoxes.orders);
    _subscription = box.watch().listen((event) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        fetchSale();
        fetchSaleCarts();
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  changeIndex(int index) {
    state = state.copyWith(selectIndex: index, hasMore: false);
    fetchSale();
  }

  fetchSaleCarts() async {
    final response = await _settingsRepository.getSaleCart();
    response.when(
      success: (data) async {
        state = state.copyWith(saleCart: data, errorMessage: null);
        final currentList = state.selectIndex == 0
            ? state.listDriver
            : state.selectIndex == 1
                ? state.listToday
                : state.listHistory;

        calculatePaymentSummary(currentList);
      },
      failure: (failure, status) {
        state = state.copyWith(errorMessage: failure);
      },
    );
  }

  fetchSale() async {
    state = state.copyWith(
      isLoading: state.selectIndex == 0
          ? state.listDriver.isEmpty
          : state.selectIndex == 1
              ? state.listToday.isEmpty
              : state.listHistory.isEmpty,
      errorMessage: null,
    );
    final response =
        await _settingsRepository.getSaleHistory(state.selectIndex, 1);
    response.when(
      success: (data) async {
        switch (state.selectIndex) {
          case 0:
            state = state.copyWith(
                isLoading: false,
                listDriver: data.list ?? [],
                hasMore: (data.list?.length ?? 0) == 10);
            break;
          case 1:
            state = state.copyWith(
                isLoading: false,
                listToday: data.list ?? [],
                hasMore: (data.list?.length ?? 0) == 10);
            calculatePaymentSummary(data.list ?? []);
            break;
          case 2:
            state = state.copyWith(
                isLoading: false,
                listHistory: data.list ?? [],
                hasMore: (data.list?.length ?? 0) == 10);
            calculatePaymentSummary(data.list ?? []);
            break;
        }
      },
      failure: (failure, status) {
        state = state.copyWith(isLoading: false, errorMessage: failure);
      },
    );
  }

  Future<void> fetchSalePage({
    VoidCallback? checkYourNetwork,
  }) async {
    if (!state.hasMore) {
      return;
    }
    if (driverPage == 1 && salePage == 1 && historyPage == 1) {
      state = state.copyWith(
          isLoading: true, listDriver: [], listHistory: [], listToday: []);

      final response = await _settingsRepository.getSaleHistory(
          state.selectIndex,
          state.selectIndex == 0
              ? ++driverPage
              : state.selectIndex == 1
                  ? ++salePage
                  : ++historyPage);

      response.when(
        success: (data) {
          state = state.copyWith(
            listDriver: data.list ?? [],
            listHistory: data.list ?? [],
            listToday: data.list ?? [],
            isLoading: false,
            errorMessage: null,
          );
          switch (state.selectIndex) {
            case 0:
              List<SaleHistoryModel> list = List.from(state.listDriver);
              list.addAll(data.list ?? []);
              state = state.copyWith(
                  listDriver: list, hasMore: (data.list?.length ?? 0) == 10);
              break;
            case 1:
              List<SaleHistoryModel> list = List.from(state.listToday);
              list.addAll(data.list ?? []);
              state = state.copyWith(
                  listToday: list, hasMore: (data.list?.length ?? 0) == 10);
              calculatePaymentSummary(list);
              break;
            case 2:
              List<SaleHistoryModel> list = List.from(state.listHistory);
              list.addAll(data.list ?? []);
              state = state.copyWith(
                  listHistory: list, hasMore: (data.list?.length ?? 0) == 10);
              calculatePaymentSummary(list);
              break;
          }
        },
        failure: (failure, status) {
          state = state.copyWith(isLoading: false, errorMessage: failure);
          debugPrint('==> get sales history failure: $failure');
        },
      );
    } else {
      state = state.copyWith(isMoreLoading: true, errorMessage: null);
      final response = await _settingsRepository.getSaleHistory(
          state.selectIndex,
          state.selectIndex == 0
              ? ++driverPage
              : state.selectIndex == 1
                  ? ++salePage
                  : ++historyPage);
      response.when(
        success: (data) async {
          switch (state.selectIndex) {
            case 0:
              List<SaleHistoryModel> list = List.from(state.listDriver);
              list.addAll(data.list ?? []);
              state = state.copyWith(
                  isMoreLoading: false,
                  listDriver: list,
                  hasMore: (data.list?.length ?? 0) == 10);
              break;
            case 1:
              List<SaleHistoryModel> list = List.from(state.listToday);
              list.addAll(data.list ?? []);
              state = state.copyWith(
                  isMoreLoading: false,
                  listToday: list,
                  hasMore: (data.list?.length ?? 0) == 10);
              calculatePaymentSummary(list);
              break;
            case 2:
              List<SaleHistoryModel> list = List.from(state.listHistory);
              list.addAll(data.list ?? []);
              state = state.copyWith(
                  isMoreLoading: false,
                  listHistory: list,
                  hasMore: (data.list?.length ?? 0) == 10);
              calculatePaymentSummary(list);
              break;
          }
        },
        failure: (failure, status) {
          state = state.copyWith(isMoreLoading: false, errorMessage: failure);
          debugPrint('==> get users  failure: $failure');
        },
      );
    }
  }

  void calculatePaymentSummary(List<SaleHistoryModel> sales) {
    double cashTotal = 0;
    double otherTotal = 0;

    for (final sale in sales) {
      if (sale.isVoided == true) continue;

      final paymentTag = sale.transactions?.isNotEmpty == true
          ? sale.transactions!.first.paymentSystem?.tag
          : null;

      final amount = sale.totalPrice ?? 0;

      if (paymentTag == 'cash') {
        cashTotal += amount;
      } else {
        otherTotal += amount;
      }
    }

    state = state.copyWith(
      saleCart: state.saleCart?.copyWith(
        cash: cashTotal,
        other: otherTotal,
      ),
    );
  }
}
