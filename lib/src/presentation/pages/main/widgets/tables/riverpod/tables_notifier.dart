// ignore_for_file: sdk_version_since

import 'dart:async';

import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:admin_desktop/src/models/data/table_bookings_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/sync/sync_service.dart';
import '../../../../../../core/utils/utils.dart';
import '../../../../../../models/data/table_data.dart';
import '../../../../../../models/models.dart';
import '../../../../../../repository/orders_repository.dart';
import '../../../../../../repository/table_repository.dart';
import 'tables_state.dart';

class TablesNotifier extends StateNotifier<TablesState> {
  final TableRepository tableRepository;
  final OrdersRepository ordersRepository;
  int _sectionPage = 0;
  int _page = 0;

  TablesNotifier(this.tableRepository, this.ordersRepository)
      : super(const TablesState());

  initial() async {
    await fetchSectionList(isRefresh: true);
    fetchTable(isRefresh: true);
    getWorkingDay();
    getCloseDay();
  }

  Future<void> refresh() async {
    clearTime();
    state = state.copyWith(isLoading: true);
    final online = await AppConnectivity.connectivity();
    if (online) {
      await SyncService().pullTablesFromServer();
    }
    await fetchSectionList(isRefresh: true);
    await fetchTable(isRefresh: true);
    await loadTableStatuses();
    if (state.isListView) {
      changeListTabIndex(state.selectListTabIndex);
    }
  }

  void changeViewMode(int index) {
    state = state.copyWith(isListView: index == 0 ? false : true);
    index == 0
        ? changeIndex(state.selectTabIndex)
        : changeListTabIndex(state.selectListTabIndex);
    clearTime();
  }

  createOrder() async {
    var res = await tableRepository.setBookings(
        bookingId: state.bookingsData?.id ?? 0,
        tableId: state.selectTableId,
        startDate: DateTime(
            state.selectDateTime?.year ?? 0,
            state.selectDateTime?.month ?? 0,
            state.selectDateTime?.day ?? 0,
            state.selectTimeOfDay?.hour ?? 0,
            state.selectTimeOfDay?.minute ?? 0),
        endDate: DateTime(
                state.selectDateTime?.year ?? 0,
                state.selectDateTime?.month ?? 0,
                state.selectDateTime?.day ?? 0,
                state.selectTimeOfDay?.hour ?? 0,
                state.selectTimeOfDay?.minute ?? 0)
            .add(Duration(
                hours:
                    int.tryParse(state.selectDuration?.substring(0, state.selectDuration?.indexOf(":")) ?? "0") ??
                        0,
                minutes: int.tryParse(state.selectDuration?.substring(
                            (state.selectDuration?.indexOf(":") ?? 0) + 1) ??
                        "0") ??
                    0)));
    res.when(
        success: (success) {
          fetchTable(isRefresh: true, start: state.start, end: state.end);
        },
        failure: (failure, status) {});
  }

  Future<bool> setDateTime(DateTime dateTime) async {
    if ((state.closeDays.singleWhere(
                (it) => it?.day?.toEqualTime(dateTime) ?? false,
                orElse: () => null)) !=
            null ||
        (state.workingDayData?.dates.firstWhere(
                (element) =>
                    element.day.toLowerCase() ==
                    DateFormat("EEEE").format(dateTime).toLowerCase(),
                orElse: () {
              return Date(id: 0, day: "", from: "", to: "", disabled: false);
            }).disabled ??
            false)) {
      state = state.copyWith(
          errorSelectDate: AppHelpers.getTranslation(TrKeys.plsSelectOtherDay));

      return false;
    }
    state = state.copyWith(selectDateTime: dateTime, errorSelectDate: null);
    var res = await tableRepository.disableDates(
      dateTime: dateTime,
      id: state.selectTableId,
    );
    res.when(
        success: (disableDates) {
          state = state.copyWith(disableDates: disableDates);
        },
        failure: (failure, status) {});
    return true;
  }

  setTimeOfDay(TimeOfDay dateTime) {
    DateTime start = state.selectDateTime!.copyWith(hour: 1);
    DateTime end = state.selectDateTime!.copyWith(hour: 23);
    for (Date element in state.workingDayData?.dates ?? []) {
      if (element.day.toLowerCase() ==
          DateFormat("EEEE").format(state.selectDateTime ?? DateTime.now())) {
        start = DateTime(
            0,
            0,
            0,
            int.tryParse(
                    element.from.substring(0, element.from.indexOf("-"))) ??
                0,
            int.tryParse(
                    element.from.substring(element.from.indexOf("-") + 1)) ??
                0);
        end = DateTime(
            0,
            0,
            0,
            int.tryParse(element.to.substring(0, element.to.indexOf("-"))) ?? 0,
            int.tryParse(element.to.substring(element.to.indexOf("-") + 1)) ??
                0);
        break;
      }
    }
    if (!((start
            .difference(state.selectDateTime
                    ?.copyWith(hour: dateTime.hour, minute: dateTime.minute) ??
                DateTime.now())
            .isNegative) ||
        (end
            .difference(state.selectDateTime
                    ?.copyWith(hour: dateTime.hour, minute: dateTime.minute) ??
                DateTime.now())
            .isNegative))) {
      state = state.copyWith(
          errorSelectTime:
              AppHelpers.getTranslation(TrKeys.plsSelectOtherTime));

      return false;
    }
    for (var element in state.disableDates) {
      if ((element?.startDate
                  .difference(state.selectDateTime?.copyWith(
                          hour: dateTime.hour, minute: dateTime.minute) ??
                      DateTime.now())
                  .isNegative ??
              false) ||
          (element?.endDate
                  .difference(state.selectDateTime?.copyWith(
                          hour: dateTime.hour, minute: dateTime.minute) ??
                      DateTime.now())
                  .isNegative ??
              false)) {
        state = state.copyWith(
            errorSelectTime:
                AppHelpers.getTranslation(TrKeys.plsSelectOtherTime));

        return false;
      }
    }

    List<DateTime> times = [];
    DateTime listStart = DateTime.now().copyWith(hour: 1, minute: 0);
    DateTime listEnd =
        DateTime.now().copyWith(hour: state.bookingsData?.maxTime ?? 23);
    while (listStart.hour != listEnd.hour) {
      times.add(listStart);
      listStart = listStart.add(const Duration(minutes: 30));
    }

    state = state.copyWith(
        selectTimeOfDay: dateTime, times: times, errorSelectTime: null);
    return true;
  }

  setDuration(String duration) async {
    state = state.copyWith(selectDuration: duration);
  }

  setSelectTable(int index) async {
    state = state.copyWith(
        selectTableId: state.tableListData[index]?.id ?? 0,
        isBookingLoading: true);
    var res = await tableRepository.getBookings();
    res.when(success: (success) {
      state =
          state.copyWith(bookingsData: success.data, isBookingLoading: false);
    }, failure: (failure, status) {
      state = state.copyWith(isBookingLoading: false);
    });
  }

  changeIndex(int index) {
    state = state.copyWith(selectTabIndex: index);
    fetchTable(isRefresh: true, start: state.start, end: state.end);
  }

  changeSelectOrder(int index) async {
    state = state.copyWith(selectOrderIndex: index);
    state = state.copyWith(selectOrderIndex: index);
    // final response = await tableRepository.getTableInfo(
    //     state.tableBookingData[index]?.id ?? 0);
    // response.when(
    //     success: (data) {
    //       state = state.copyWith(selectOrder: data.data, isInfoLoading: false);
    //     },
    //     failure: (e) {});
  }

  changeListTabIndex(int index) {
    state = state.copyWith(
        selectListTabIndex: index,
        tableBookingData: [],
        selectOrderIndex: null);
    fetchBookings(isRefresh: true, start: state.start, end: state.end);
  }

  changeSection(int index) {
    if (!state.isLoading) {
      state = state.copyWith(selectSection: index, tableListData: []);
      fetchTable(isRefresh: true, start: state.start, end: state.end);
    }
  }

  void startTableTimer(int tableId) {
    final t = Map<int, DateTime>.from(state.tableTimers);
    t[tableId] = DateTime.now();
    state = state.copyWith(tableTimers: t);
  }

  void clearTableTimer(int tableId) {
    final t = Map<int, DateTime>.from(state.tableTimers);
    t.remove(tableId);
    state = state.copyWith(tableTimers: t);
  }

  Future<void> loadTableStatuses() async {
    final response =
        await ordersRepository.getOrders(status: OrderStatus.newOrder);
    response.when(
      success: (data) {
        final orders = data.data?.orders ?? [];
        final ids = <int, int>{};
        final timers = <int, DateTime>{};
        for (final order in orders) {
          final tableId = order.table?.id;
          final orderId = order.id;
          if (tableId != null && orderId != null) {
            ids[tableId] = orderId;
            timers[tableId] = order.createdAt != null
                ? DateTime.tryParse(order.createdAt!) ?? DateTime.now()
                : DateTime.now();
          }
        }
        state = state.copyWith(tableOrders: ids, tableTimers: timers);
      },
      failure: (failure, status) {
        debugPrint('==> loadTableStatuses failed: $failure');
      },
    );
  }

  void setTableOrder(int tableId, int orderId) {
    final orders = Map<int, int>.from(state.tableOrders);
    orders[tableId] = orderId;
    final timers = Map<int, DateTime>.from(state.tableTimers);
    timers.putIfAbsent(tableId, () => DateTime.now());
    state = state.copyWith(tableOrders: orders, tableTimers: timers);
  }

  void clearTableOrder(int tableId) {
    final orders = Map<int, int>.from(state.tableOrders);
    orders.remove(tableId);
    state = state.copyWith(tableOrders: orders);
  }

  void setKitchenLabel(String label) {
    state = state.copyWith(kitchenOrderLabel: label);
  }

  void enterTableOrdering(TableData table) {
    final tableId = table.id ?? 0;
    final isReorder = state.tableTimers.containsKey(tableId);
    setKitchenLabel(isReorder ? 'REORDER' : 'NEW ORDER');
    LocalStorage.setActiveOrderingTableId(table.id);
    state = state.copyWith(activeOrderTable: table);
  }

  void exitTableOrdering() {
    LocalStorage.setActiveOrderingTableId(null);
    state = state.copyWith(activeOrderTable: null);
  }

  void toggleEditMode() {
    final wasEditing = state.isEditMode;
    state = state.copyWith(isEditMode: !wasEditing);
    if (wasEditing) {
      fetchTable(isRefresh: true);
    }
  }

  Future<void> updateTablePosition(
      int tableId, double normX, double normY) async {
    final updated = Map<int, Offset>.from(state.tablePositions);
    updated[tableId] = Offset(normX, normY);
    state = state.copyWith(tablePositions: updated);

    final result =
        await tableRepository.updateTablePosition(tableId, normX, normY);
    result.when(
      success: (_) {},
      failure: (error, _) {
        final reverted = Map<int, Offset>.from(state.tablePositions);
        reverted.remove(tableId);
        state = state.copyWith(tablePositions: reverted);
        debugPrint('==> updateTablePosition reverted: $error');
      },
    );
  }

  Future<void> updateMapSize(int sectionId, int width, int height) async {
    final optimistic = state.shopSectionList.map((s) {
      if (s?.id != sectionId) return s;
      return ShopSection(
        id: s!.id,
        shopId: s.shopId,
        area: s.area,
        img: s.img,
        createdAt: s.createdAt,
        updatedAt: s.updatedAt,
        translation: s.translation,
        mapWidth: width,
        mapHeight: height,
      );
    }).toList();
    state = state.copyWith(shopSectionList: optimistic);

    final result =
        await tableRepository.updateSectionMapSize(sectionId, width, height);
    result.when(
      success: (section) {
        final confirmed = state.shopSectionList.map((s) {
          if (s?.id != sectionId) return s;
          return ShopSection(
            id: s!.id,
            shopId: s.shopId,
            area: s.area,
            img: s.img,
            createdAt: s.createdAt,
            updatedAt: s.updatedAt,
            translation: s.translation,
            mapWidth: section.mapWidth ?? s.mapWidth,
            mapHeight: section.mapHeight ?? s.mapHeight,
          );
        }).toList();
        state = state.copyWith(shopSectionList: confirmed);
      },
      failure: (error, _) =>
          debugPrint('==> updateMapSize failure: $error'),
    );
  }

  setSection({String? title, int? index}) {
    if (title != null) {
      for (int i = 0; i < state.shopSectionList.length; i++) {
        if (state.shopSectionList[i]?.translation?.title == title) {
          state = state.copyWith(
              selectAddSection: state.shopSectionList[i]?.id ?? 1);
          return;
        }
      }
    } else if (index != null) {
      state = state.copyWith(
          selectAddSection: state.shopSectionList[index]?.id ?? 1);
    }
  }

  addNewSection(
      {required String name,
      required num area,
      required BuildContext context}) async {
    state = state.copyWith(isSectionLoading: true);
    final res = await tableRepository.createNewSection(name: name, area: area);
    await fetchSectionList(isRefresh: true);

    res.when(success: (success) async {
      // List<ShopSection> shopSectionList = List.from(state.shopSectionList);
      // shopSectionList.insert(0,success);
      // state=state.copyWith(shopSectionList: shopSectionList,isSectionLoading: false);
    }, failure: (failure, status) {
      if (context.mounted) {
        AppHelpers.showSnackBar(
          context,
          AppHelpers.getTranslation(failure.toString()),
        );
      }
      state = state.copyWith(isSectionLoading: false);
    });
    state = state.copyWith(isSectionLoading: false);
  }

  Future<void> deleteSectionById(
      {required int id, required BuildContext context}) async {
    state = state.copyWith(isSectionLoading: true);
    final res = await tableRepository.deleteSection(id);
    res.when(
      success: (_) async {
        await fetchSectionList(isRefresh: true);
        if (state.selectSection >= state.shopSectionList.length &&
            state.shopSectionList.isNotEmpty) {
          state = state.copyWith(selectSection: 0);
        }
      },
      failure: (failure, status) {
        if (context.mounted) {
          AppHelpers.showSnackBar(
              context, AppHelpers.getTranslation(failure.toString()));
        }
        state = state.copyWith(isSectionLoading: false);
      },
    );
    state = state.copyWith(isSectionLoading: false);
  }

  Future<void> updateSectionById(
      {required int id,
      required String name,
      required num area,
      required BuildContext context}) async {
    state = state.copyWith(isSectionLoading: true);
    final res =
        await tableRepository.updateSection(id: id, name: name, area: area);
    res.when(
      success: (_) async {
        await fetchSectionList(isRefresh: true);
      },
      failure: (failure, status) {
        if (context.mounted) {
          AppHelpers.showSnackBar(
              context, AppHelpers.getTranslation(failure.toString()));
        }
        state = state.copyWith(isSectionLoading: false);
      },
    );
    state = state.copyWith(isSectionLoading: false);
  }

  Future<void> fetchSectionList({bool isRefresh = false}) async {
    if (isRefresh) {
      _sectionPage = 0;
      state = state.copyWith(hasMoreSections: true);
    }
    if (!state.hasMoreSections) {
      return;
    }
    state = state.copyWith(
      isSectionLoading: true,
    );

    final response = await tableRepository.getSection(page: ++_sectionPage);
    response.when(
      success: (data) {
        state = state.copyWith(
          shopSectionList: data.data ?? [],
          isSectionLoading: false,
        );
        if ((data.data?.length ?? 0) < 50) {
          state = state.copyWith(hasMoreSections: false);
        }
      },
      failure: (failure, status) {
        _sectionPage--;
        if (_sectionPage == 0) {
          state = state.copyWith(isSectionLoading: false);
        }
      },
    );
    List<String> list = [];
    for (var e in state.shopSectionList) {
      list.add(e?.translation?.title ?? "");
    }
    state = state.copyWith(sectionListTitle: list);
  }

  Future<void> fetchTable({
    bool isRefresh = false,
    DateTime? start,
    DateTime? end,
  }) async {
    if (isRefresh) {
      _page = 0;
      state = state.copyWith(hasMore: true, isLoading: true);
    }
    if (!state.hasMore) {
      return;
    }
    final response = await tableRepository.getTables(
        page: ++_page,
        type: state.selectTabIndex == 1
            ? TrKeys.available
            : state.selectTabIndex == 2
                ? TrKeys.booked
                : state.selectTabIndex == 3
                    ? TrKeys.occupied
                    : null,
        to: end,
        from: start,
        shopSectionId: state.shopSectionList.isEmpty
            ? 1
            : (state.shopSectionList[state.selectSection]?.id));

    response.when(
      success: (data) async {
        List<TableData> tableListData =
            isRefresh ? [] : List.from(state.tableListData);
        final List<TableData> newTables = data.data ?? [];
        tableListData.addAll(newTables);
        state = state.copyWith(hasMore: newTables.length >= 10);

        final positions = isRefresh
            ? <int, Offset>{}
            : Map<int, Offset>.from(state.tablePositions);
        for (final t in newTables) {
          final id = t.id;
          if (id != null && t.positionX != null && t.positionY != null) {
            positions[id] = Offset(t.positionX!, t.positionY!);
          }
        }

        state = state.copyWith(
          isLoading: false,
          tableListData: tableListData,
          tablePositions: positions,
        );
        await getStatistic(start: start, end: end);
      },
      failure: (failure, status) {
        _page--;
        if (_page == 0) {
          state = state.copyWith(isLoading: false);
        }
      },
    );
  }

  Future<void> fetchBookings({
    bool isRefresh = false,
    DateTime? start,
    DateTime? end,
  }) async {
    if (isRefresh) {
      _page = 0;
      state = state.copyWith(hasMoreBookings: true, isLoading: true);
    }
    if (!state.hasMoreBookings) {
      return;
    }
    final response = await tableRepository.getTableOrders(
      page: ++_page,
      type: state.selectListTabIndex == 1
          ? TrKeys.newKey
          : state.selectListTabIndex == 2
              ? TrKeys.accepted
              : state.selectListTabIndex == 3
                  ? TrKeys.canceled
                  : null,
      to: end,
      from: start,
    );

    response.when(
      success: (data) {
        List<TableBookingData> tableBookingData =
            isRefresh ? [] : List.from(state.tableListData);
        final List<TableBookingData> newTables = data.data;
        tableBookingData.addAll(newTables);
        state = state.copyWith(hasMore: newTables.length >= 10);
        if (tableBookingData.isNotEmpty) {
          state = state.copyWith(selectOrderIndex: 0);
        }
        state = state.copyWith(
          isLoading: false,
          tableBookingData: tableBookingData,
        );
      },
      failure: (failure, status) {
        _page--;
        if (_page == 0) {
          state = state.copyWith(isLoading: false);
        }
      },
    );
  }

  addTable({
    required TableModel tableModel,
    required BuildContext context,
  }) async {
    final res = await tableRepository.createNewTable(tableModel: tableModel);

    res.when(success: (success) {
      fetchTable(isRefresh: true);
    }, failure: (failure, status) {
      if (context.mounted) {
        AppHelpers.showSnackBar(
          context,
          AppHelpers.getTranslation(failure.toString()),
        );
      }
    });
  }

  Future<void> updateTable({
    required int id,
    required String name,
    required int chairCount,
    required BuildContext context,
  }) async {
    final result = await tableRepository.updateTable(
        id: id, name: name, chairCount: chairCount);
    result.when(
      success: (_) => fetchTable(isRefresh: true),
      failure: (error, _) {
        if (context.mounted) {
          AppHelpers.showSnackBar(context, AppHelpers.getTranslation(error));
        }
      },
    );
  }

  deleteTable({required int index}) async {
    List<TableData> list = List.from(state.tableListData);
    int id = list[index].id ?? 0;
    list.removeAt(index);
    state = state.copyWith(tableListData: list);
    await tableRepository.deleteTable(id);
    await getStatistic(start: state.start, end: state.end);
  }

  getWorkingDay() async {
    var res = await tableRepository.getWorkingDay();
    res.when(
        success: (success) {
          state = state.copyWith(workingDayData: success.data);
        },
        failure: (failure, status) {});
  }

  getCloseDay() async {
    var res = await tableRepository.getCloseDay();
    res.when(
        success: (success) {
          state = state.copyWith(
              closeDays: success.data?.bookingShopClosedDate ?? []);
        },
        failure: (failure, status) {});
  }

  getStatistic({DateTime? start, DateTime? end}) async {
    state = state.copyWith(isStatisticLoading: true);
    var res = await tableRepository.getStatistic(to: end, from: start);
    res.when(
        success: (success) {
          state = state.copyWith(
              tableStatistic: success.data, isStatisticLoading: false);
        },
        failure: (failure, status) {});
  }

  changeStatus(String status) async {
    if (DateTime.now().compareTo(
            state.tableBookingData[state.selectOrderIndex!]?.endDate ??
                DateTime.now()) <=
        0) {
      List<TableBookingData> list = List.from(state.tableBookingData);
      list[state.selectOrderIndex!] =
          list[state.selectOrderIndex!].copyWith(status: status);
      state = state.copyWith(tableBookingData: list);
      await tableRepository.changeOrderStatus(
        status: status,
        id: state.tableBookingData[state.selectOrderIndex!]?.id ?? 0,
      );
    }
  }

  setTime(DateTime? start, DateTime? end) {
    state = state.copyWith(start: start, end: end);
  }

  clearTime() {
    state = state.copyWith(start: null, end: null);
  }
}
