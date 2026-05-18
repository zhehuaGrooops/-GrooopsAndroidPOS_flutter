import 'package:admin_desktop/src/models/data/table_data.dart';
import 'package:admin_desktop/src/models/response/close_day_response.dart';
import 'package:admin_desktop/src/models/data/table_statistics_data.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../../../models/data/table_bookings_data.dart';
import '../../../../../../models/models.dart';

part 'tables_state.freezed.dart';

@freezed
class TablesState with _$TablesState {
  const factory TablesState({
    @Default(false) bool isLoading,
    @Default(false) bool isInfoLoading,
    @Default(false) bool isBookingLoading,
    @Default(false) bool isSectionLoading,
    @Default(false) bool isStatisticLoading,
    @Default(true) bool hasMore,
    @Default(true) bool hasMoreSections,
    @Default(true) bool hasMoreBookings,
    @Default(false) bool showFilter,
    @Default(false) bool isListView,
    @Default(0) int selectTabIndex,
    @Default(0) int selectListTabIndex,
    @Default(0) int selectSection,
    @Default(1) int selectAddSection,
    @Default(1) int selectTableId,
    @Default(null) int? selectOrderIndex,
    @Default([]) List<TableData?> tableListData,
    @Default([]) List<TableBookingData?> tableBookingData,
    @Default([]) List<String> sectionListTitle,
    @Default([]) List<ShopSection?> shopSectionList,
    @Default([]) List<DisableDates?> disableDates,
    @Default(null) TableStatisticData? tableStatistic,
    @Default(null) WorkingDayData? workingDayData,
    @Default(null) BookingsData? bookingsData,
    @Default(null) DateTime? selectDateTime,
    @Default(null) TimeOfDay? selectTimeOfDay,
    @Default(null) String? selectDuration,
    @Default(null) String? errorSelectDate,
    @Default(null) String? errorSelectTime,
    @Default([]) List<BookingShopClosedDate?> closeDays,
    @Default([]) List<DateTime?> times,
    @Default(null) DateTime? start,
    @Default(null) DateTime? end,
  }) = _TablesState;

  const TablesState._();
}
