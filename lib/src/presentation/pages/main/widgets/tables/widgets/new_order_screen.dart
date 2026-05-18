import 'package:admin_desktop/generated/assets.dart';
import 'package:admin_desktop/src/core/utils/app_helpers.dart';
import 'package:admin_desktop/src/core/utils/validator_utils.dart';
import 'package:admin_desktop/src/presentation/components/components.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/constants/constants.dart';
import '../../../../../theme/app_style.dart';
import '../riverpod/tables_provider.dart';
import 'custom_drop_down_field.dart';
import 'table_form_field.dart';

class NewOrderScreen extends ConsumerStatefulWidget {
  const NewOrderScreen({super.key});

  @override
  ConsumerState<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends ConsumerState<NewOrderScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late TextEditingController time;
  late TextEditingController date;

  @override
  void initState() {
    time = TextEditingController();
    date = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    time.dispose();
    date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(tablesProvider.notifier);
    final state = ref.watch(tablesProvider);
    return state.bookingsData == null
        ? Container(
            padding: REdgeInsets.symmetric(horizontal: 16),
            height: MediaQuery.of(context).size.height / 2,
            child: Center(
              child: state.isBookingLoading
                  ? const CircularProgressIndicator(
                      color: AppStyle.primary,
                      strokeWidth: 3.3,
                    )
                  : Text(AppHelpers.getTranslation(TrKeys.noBooking)),
            ))
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: REdgeInsets.only(top: 5),
                    child: Text(
                      AppHelpers.getTranslation(TrKeys.newOrder),
                      style: GoogleFonts.inter(
                        color: AppStyle.black,
                        fontWeight: FontWeight.w500,
                        fontSize: 16.sp,
                      ),
                    ),
                  ),
                  GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child:
                          Icon(Icons.close, color: AppStyle.black, size: 24.r)),
                ],
              ),
              Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      24.verticalSpace,
                      TableFormField(
                        onTap: () {
                          showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 1000),
                            ),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: AppStyle.primary,
                                    onPrimary: AppStyle.black,
                                    onSurface: AppStyle.black,
                                  ),
                                  textButtonTheme: TextButtonThemeData(
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppStyle.black,
                                    ),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          ).then((selectDate) {
                            if (selectDate != null) {
                              notifier.setDateTime(selectDate).then((value) {
                                if (value) {
                                  date.text = DateFormat("MM/dd/yyyy")
                                      .format(selectDate);
                                }
                              });
                            }
                          });
                        },
                        prefixIcon: FlutterRemix.calendar_check_line,
                        prefixSvg: Assets.svgTax,
                        inputType: TextInputType.number,
                        validator: ValidatorUtils.validateEmpty,
                        hintText:
                            DateFormat("MM/dd/yyyy").format(DateTime.now()),
                        textEditingController: date,
                        readOnly: true,
                      ),
                      if (state.errorSelectDate != null)
                        SizedBox(
                          width: 200.w,
                          child: Text(
                            state.errorSelectDate ?? "",
                            style: GoogleFonts.inter(color: AppStyle.red),
                          ),
                        ),
                      12.verticalSpace,
                      TableFormField(
                        onTap: () {
                          if (ref.watch(tablesProvider).selectDateTime !=
                              null) {
                            showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: AppStyle.primary,
                                      onPrimary: AppStyle.black,
                                      onSurface: AppStyle.black,
                                    ),
                                    textButtonTheme: TextButtonThemeData(
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppStyle.black,
                                      ),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            ).then((selectTime) {
                              if (selectTime != null) {
                                if (notifier.setTimeOfDay(selectTime)) {
                                  if (!context.mounted) return;
                                  time.text = selectTime.format(context);
                                }
                              }
                            });
                          }
                        },
                        prefixIcon: FlutterRemix.time_line,
                        prefixSvg: Assets.svgTax,
                        inputType: TextInputType.number,
                        validator: ValidatorUtils.validateEmpty,
                        hintText: TimeOfDay.now().format(context),
                        textEditingController: time,
                        readOnly: true,
                      ),
                      if (state.errorSelectTime != null)
                        SizedBox(
                          width: 200.w,
                          child: Text(
                            state.errorSelectTime ?? "",
                            style: GoogleFonts.inter(color: AppStyle.red),
                          ),
                        ),
                      12.verticalSpace,
                      CustomDropDownField(
                        validator: ValidatorUtils.validateEmpty,
                        list: state.times
                            .map((e) =>
                                DateFormat("HH:mm").format(e ?? DateTime.now()))
                            .toList(),
                        onChanged: (value) {
                          if (ref.watch(tablesProvider).selectDateTime !=
                              null) {
                            notifier.setDuration(value);
                          }
                        },
                        iconData: FlutterRemix.time_line,
                      ),
                      30.verticalSpace,
                      LoginButton(
                          isActive: state.bookingsData != null,
                          title: AppHelpers.getTranslation(TrKeys.confirm),
                          onPressed: () {
                            if (formKey.currentState?.validate() ?? false) {
                              notifier.createOrder();
                              context.maybePop();
                            }
                          }),
                    ],
                  ),
                ),
              ),
            ],
          );
  }
}
