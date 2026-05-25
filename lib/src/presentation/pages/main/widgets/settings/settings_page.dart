import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:admin_desktop/src/presentation/theme/app_style.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:admin_desktop/src/models/models.dart';
import 'package:admin_desktop/src/models/data/bluetooth_printer.dart';
import 'package:admin_desktop/src/core/utils/local_storage.dart';
import '../../riverpod/provider/main_provider.dart';
import 'riverpod/kitchen_printer_provider.dart';
import 'riverpod/printer_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  PrinterType _selectedType = PrinterType.bluetooth;
  bool _isBle = false;
  PrinterType _selectedKitchenType = PrinterType.bluetooth;
  bool _isKitchenBle = false;
  final TextEditingController _receiptCharsController = TextEditingController();
  final TextEditingController _kitchenCharsController = TextEditingController();
  final FocusNode _receiptCharsFocus = FocusNode();
  final FocusNode _kitchenCharsFocus = FocusNode();
  Timer? _receiptCharsDebounce;
  Timer? _kitchenCharsDebounce;
  String? _lastKitchenPrinterId;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _selectedType = PrinterType.usb;
      _selectedKitchenType = PrinterType.usb;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Init if not already
      ref.read(printerProvider.notifier).init();
      ref.read(kitchenPrinterProvider.notifier).loadPrinters();
      final mainState = ref.read(mainProvider);
      if (mainState.categories.isEmpty && !mainState.isCategoriesLoading) {
        ref.read(mainProvider.notifier).fetchCategories(context: context);
      }
    });
  }

  @override
  void dispose() {
    _receiptCharsDebounce?.cancel();
    _kitchenCharsDebounce?.cancel();
    _receiptCharsController.dispose();
    _kitchenCharsController.dispose();
    _receiptCharsFocus.dispose();
    _kitchenCharsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(printerProvider);
    final notifier = ref.read(printerProvider.notifier);

    final kitchenState = ref.watch(kitchenPrinterProvider);
    final kitchenNotifier = ref.read(kitchenPrinterProvider.notifier);

    final mainState = ref.watch(mainProvider);
    final categories = mainState.categories;
    final receiptCharsPerLine = state.savedConfig?.charsPerLine;
    final receiptCharsText = '${receiptCharsPerLine ?? 48}';
    if (!_receiptCharsFocus.hasFocus &&
        _receiptCharsController.text.trim() != receiptCharsText) {
      _receiptCharsController.text = receiptCharsText;
    }

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20.r, horizontal: 16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Settings",
              style: GoogleFonts.inter(
                  fontSize: 22.r, fontWeight: FontWeight.w600),
            ),
            16.verticalSpace,
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                color: AppStyle.white,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Selected Receipt Printer",
                    style: GoogleFonts.inter(
                        fontSize: 18.sp, fontWeight: FontWeight.w600),
                  ),
                  20.verticalSpace,
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: AppStyle.black.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              state.isConnected
                                  ? Icons.print
                                  : Icons.print_disabled,
                              color: state.isConnected
                                  ? AppStyle.primary
                                  : Colors.grey,
                              size: 24.r,
                            ),
                            12.horizontalSpace,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    state.isConnected
                                        ? (state.savedConfig?.name ??
                                            'Unknown Printer')
                                        : "No printer selected",
                                    style: GoogleFonts.inter(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (state.isConnected) ...[
                                    4.verticalSpace,
                                    Text(
                                      state.savedConfig?.address ?? '',
                                      style: GoogleFonts.inter(
                                        fontSize: 14.sp,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // if (state.savedConfig != null)
                            //   TextButton(
                            //     onPressed: () async {
                            //       final ok = await testPrintAndNotify(
                            //         context: context,
                            //         config: state.savedConfig!,
                            //       );
                            //       if (ok) {
                            //         try {
                            //           await notifier.connectToSavedPrinter();
                            //         } catch (_) {}
                            //       }
                            //     },
                            //     child: const Text("Test Print"),
                            //   ),
                            if (state.isConnected)
                              TextButton(
                                onPressed: () => notifier.disconnect(),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text("Disconnect"),
                              ),
                          ],
                        ),
                        16.verticalSpace,
                        TextFormField(
                          controller: _receiptCharsController,
                          focusNode: _receiptCharsFocus,
                          enabled: state.savedConfig != null,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Receipt Printer Characters Per Line",
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            _receiptCharsDebounce?.cancel();
                            _receiptCharsDebounce = Timer(
                              const Duration(milliseconds: 400),
                              () {
                                final parsed = int.tryParse(value.trim());
                                if (parsed == null) return;
                                notifier.updateCharsPerLine(parsed);
                              },
                            );
                          },
                          onFieldSubmitted: (value) {
                            final parsed = int.tryParse(value.trim());
                            if (parsed == null) return;
                            notifier.updateCharsPerLine(parsed);
                          },
                        ),
                        if (state.isConnected) ...[
                          12.verticalSpace,
                          Row(
                            children: [
                              Container(
                                width: 8.r,
                                height: 8.r,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              8.horizontalSpace,
                              Text(
                                "Connected",
                                style: GoogleFonts.inter(
                                  fontSize: 14.sp,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  32.verticalSpace,
                  Text(
                    "Search Printer",
                    style: GoogleFonts.inter(
                        fontSize: 18.sp, fontWeight: FontWeight.w600),
                  ),
                  20.verticalSpace,
                  // Type Selection
                  DropdownButtonFormField<PrinterType>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: "Printer Type",
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      if (Platform.isAndroid ||
                          Platform.isIOS ||
                          Platform.isWindows)
                        const DropdownMenuItem(
                          value: PrinterType.bluetooth,
                          child: Text("Bluetooth"),
                        ),
                      if (Platform.isAndroid || Platform.isWindows)
                        const DropdownMenuItem(
                          value: PrinterType.usb,
                          child: Text("USB"),
                        ),
                      const DropdownMenuItem(
                        value: PrinterType.network,
                        child: Text("Network (WiFi/LAN)"),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedType = val;
                          notifier.stopScan();
                        });
                      }
                    },
                  ),
                  16.verticalSpace,
                  if (_selectedType == PrinterType.bluetooth &&
                      Platform.isAndroid)
                    SwitchListTile(
                      title: const Text("Use BLE (Bluetooth Low Energy)"),
                      value: _isBle,
                      onChanged: (val) {
                        setState(() {
                          _isBle = val;
                        });
                      },
                    ),

                  ElevatedButton.icon(
                    onPressed: state.isScanning
                        ? () => notifier.stopScan()
                        : () {
                            notifier.clearDevices();
                            notifier.scan(_selectedType, isBle: _isBle);
                          },
                    icon: Icon(state.isScanning ? Icons.stop : Icons.search),
                    label:
                        Text(state.isScanning ? "Stop Scan" : "Scan Devices"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppStyle.primary,
                        ),
                  ),

                  20.verticalSpace,
                  if (state.isScanning) const LinearProgressIndicator(color: AppStyle.primary, backgroundColor: Color(0x33ED683C)),

                  if (state.devices.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.devices.length,
                      itemBuilder: (context, index) {
                        final device = state.devices[index];
                        return ListTile(
                          title: Text(device.deviceName ?? "Unknown Device"),
                          subtitle: Text(device.address ?? ""),
                          trailing: state.isConnecting &&
                                  state.selectedDevice?.address ==
                                      device.address
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppStyle.primary,
                                  ),
                                  onPressed: () => notifier.connect(device),
                                  child: const Text("Connect"),
                                ),
                        );
                      },
                    ),

                  if (state.error != null)
                    Padding(
                      padding: EdgeInsets.only(top: 20.r),
                      child: Text(
                        state.error!,
                        style: TextStyle(color: Colors.red, fontSize: 14.sp),
                      ),
                    ),
                ],
              ),
            ),
            16.verticalSpace,
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                color: AppStyle.white,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Kitchen Printers",
                          style: GoogleFonts.inter(
                              fontSize: 18.sp, fontWeight: FontWeight.w600),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => kitchenNotifier.addPrinter(),
                        icon: const Icon(Icons.add),
                        label: const Text("Add Kitchen Printer"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppStyle.primary,
                        ),
                      ),
                    ],
                  ),
                  20.verticalSpace,
                  if (kitchenState.printers.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: kitchenState.printers.length,
                      itemBuilder: (context, index) {
                        final printer = kitchenState.printers[index];
                        final isSelected =
                            kitchenState.selectedPrinterId == printer.id;
                        final name = printer.printerConfig?.name ??
                            'No printer selected';
                        final address = printer.printerConfig?.address ?? '';
                        final categoriesCount = printer.categoryIds.length;
                        return Card(
                          elevation: 0,
                          color: isSelected
                              ? AppStyle.primary.withOpacity(0.06)
                              : null,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                                color: AppStyle.black.withOpacity(0.08)),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: ListTile(
                            onTap: () =>
                                kitchenNotifier.selectPrinter(printer.id),
                            leading: Icon(
                              printer.printerConfig != null
                                  ? Icons.print
                                  : Icons.print_disabled,
                              color: printer.printerConfig != null
                                  ? AppStyle.primary
                                  : Colors.grey,
                            ),
                            title: Text(name),
                            subtitle: Text(
                              address.isNotEmpty
                                  ? '$address • $categoriesCount categories'
                                  : '$categoriesCount categories',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // if (printer.printerConfig != null)
                                //   TextButton(
                                //     onPressed: () async {
                                //       final config = printer.printerConfig;
                                //       if (config == null) return;
                                //       await testPrintAndNotify(
                                //         context: context,
                                //         config: config,
                                //       );
                                //     },
                                //     child: const Text("Test Print"),
                                //   ),
                                if (printer.printerConfig != null)
                                  TextButton(
                                    onPressed: () async {
                                      kitchenNotifier.selectPrinter(printer.id);
                                      await kitchenNotifier.disconnect(
                                          clearConfig: true);
                                    },
                                    style: TextButton.styleFrom(
                                        foregroundColor: Colors.red),
                                    child: const Text("Disconnect"),
                                  ),
                                IconButton(
                                  onPressed: () =>
                                      kitchenNotifier.removePrinter(printer.id),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  else
                    Text(
                      "No kitchen printers configured yet.",
                      style: GoogleFonts.inter(
                          fontSize: 14.sp, color: Colors.grey[700]),
                    ),
                  32.verticalSpace,
                  Text(
                    "Selected Kitchen Printer",
                    style: GoogleFonts.inter(
                        fontSize: 18.sp, fontWeight: FontWeight.w600),
                  ),
                  20.verticalSpace,
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: AppStyle.black.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Builder(
                      builder: (context) {
                        final selected = kitchenState.selectedPrinter;
                        if (selected == null) {
                          return Text(
                            "Add a kitchen printer to start configuration.",
                            style: GoogleFonts.inter(
                                fontSize: 14.sp, color: Colors.grey[700]),
                          );
                        }
                        final config = selected.printerConfig;
                        final displayName =
                            config?.name ?? "No printer selected";
                        final displayAddress = config?.address ?? "";
                        final selectedCategoryTitles = _selectedCategoryTitles(
                          categories: categories,
                          selectedIds: selected.categoryIds,
                        );
                        if (_lastKitchenPrinterId != selected.id) {
                          _lastKitchenPrinterId = selected.id;
                          if (!_kitchenCharsFocus.hasFocus) {
                            _kitchenCharsController.text =
                                '${selected.charsPerLine ?? 48}';
                          }
                        } else if (!_kitchenCharsFocus.hasFocus &&
                            _kitchenCharsController.text.trim() !=
                                '${selected.charsPerLine ?? 48}') {
                          _kitchenCharsController.text =
                              '${selected.charsPerLine ?? 48}';
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  (config != null || kitchenState.isConnected)
                                      ? Icons.print
                                      : Icons.print_disabled,
                                  color: (config != null ||
                                          kitchenState.isConnected)
                                      ? AppStyle.primary
                                      : Colors.grey,
                                  size: 24.r,
                                ),
                                12.horizontalSpace,
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        kitchenState.isConnected
                                            ? displayName
                                            : displayName,
                                        style: GoogleFonts.inter(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (displayAddress.isNotEmpty) ...[
                                        4.verticalSpace,
                                        Text(
                                          displayAddress,
                                          style: GoogleFonts.inter(
                                            fontSize: 14.sp,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (kitchenState.isConnected)
                                  TextButton(
                                    onPressed: () => kitchenNotifier.disconnect(
                                        clearConfig: false),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text("Disconnect"),
                                  ),
                              ],
                            ),
                            16.verticalSpace,
                            TextFormField(
                              controller: _kitchenCharsController,
                              focusNode: _kitchenCharsFocus,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText:
                                    "Kitchen Printer Characters Per Line",
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                _kitchenCharsDebounce?.cancel();
                                _kitchenCharsDebounce = Timer(
                                  const Duration(milliseconds: 400),
                                  () {
                                    final parsed = int.tryParse(value.trim());
                                    if (parsed == null) return;
                                    kitchenNotifier.updateCharsPerLine(parsed);
                                  },
                                );
                              },
                              onFieldSubmitted: (value) {
                                final parsed = int.tryParse(value.trim());
                                if (parsed == null) return;
                                kitchenNotifier.updateCharsPerLine(parsed);
                              },
                            ),
                            12.verticalSpace,
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    selectedCategoryTitles.isEmpty
                                        ? "Categories: none selected"
                                        : "Categories: ${selectedCategoryTitles.join(', ')}",
                                    style: GoogleFonts.inter(fontSize: 14.sp),
                                  ),
                                ),
                                TextButton(
                                  onPressed: categories.isEmpty
                                      ? null
                                      : () => _showCategoryMultiSelectDialog(
                                            context: context,
                                            allCategories: categories,
                                            initialSelected:
                                                selected.categoryIds,
                                            onSave: (ids) => kitchenNotifier
                                                .updateSelectedCategories(ids),
                                          ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppStyle.primary,
                                  ),
                                  child: const Text("Select Categories"),
                                ),
                              ],
                            ),
                            if (kitchenState.isConnected) ...[
                              12.verticalSpace,
                              Row(
                                children: [
                                  Container(
                                    width: 8.r,
                                    height: 8.r,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  8.horizontalSpace,
                                  Text(
                                    "Connected",
                                    style: GoogleFonts.inter(
                                      fontSize: 14.sp,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                  32.verticalSpace,
                  Text(
                    "Search Printer",
                    style: GoogleFonts.inter(
                        fontSize: 18.sp, fontWeight: FontWeight.w600),
                  ),
                  20.verticalSpace,
                  DropdownButtonFormField<PrinterType>(
                    value: _selectedKitchenType,
                    decoration: const InputDecoration(
                      labelText: "Printer Type",
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      if (Platform.isAndroid || Platform.isIOS)
                        const DropdownMenuItem(
                          value: PrinterType.bluetooth,
                          child: Text("Bluetooth"),
                        ),
                      if (Platform.isAndroid || Platform.isWindows)
                        const DropdownMenuItem(
                          value: PrinterType.usb,
                          child: Text("USB"),
                        ),
                      const DropdownMenuItem(
                        value: PrinterType.network,
                        child: Text("Network (WiFi/LAN)"),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedKitchenType = val;
                          kitchenNotifier.stopScan();
                        });
                      }
                    },
                  ),
                  16.verticalSpace,
                  if (_selectedKitchenType == PrinterType.bluetooth &&
                      Platform.isAndroid)
                    SwitchListTile(
                      title: const Text("Use BLE (Bluetooth Low Energy)"),
                      value: _isKitchenBle,
                      onChanged: (val) {
                        setState(() {
                          _isKitchenBle = val;
                        });
                      },
                    ),
                  ElevatedButton.icon(
                    onPressed: kitchenState.isScanning
                        ? () => kitchenNotifier.stopScan()
                        : () async {
                            kitchenNotifier.clearDevices();
                            await kitchenNotifier.scan(
                              _selectedKitchenType,
                              isBle: _isKitchenBle,
                            );
                            final receiptConfig = state.savedConfig;
                            final receiptIsNetwork = receiptConfig != null &&
                                receiptConfig.type == PrinterType.network.index;
                            if (_selectedKitchenType == PrinterType.network &&
                                receiptIsNetwork) {
                              final config = receiptConfig;
                              final receiptAddress =
                                  config.address?.trim() ?? '';
                              if (receiptAddress.isNotEmpty) {
                                kitchenNotifier.addOrUpdateDevice(
                                  BluetoothPrinter(
                                    deviceName:
                                        config.name ?? 'Receipt Printer',
                                    address: receiptAddress,
                                    vendorId: config.vendorId,
                                    productId: config.productId,
                                    isBle: config.isBle,
                                    typePrinter: PrinterType.network,
                                  ),
                                );
                              }
                            }
                          },
                    icon: Icon(
                        kitchenState.isScanning ? Icons.stop : Icons.search),
                    label: Text(
                        kitchenState.isScanning ? "Stop Scan" : "Scan Devices"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppStyle.primary,
                        ),
                  ),
                  20.verticalSpace,
                  if (kitchenState.isScanning) const LinearProgressIndicator(color: AppStyle.primary,backgroundColor: Color(0x33ED683C),),
                  if (kitchenState.devices.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: kitchenState.devices.length,
                      itemBuilder: (context, index) {
                        final device = kitchenState.devices[index];
                        return ListTile(
                          title: Text(device.deviceName ?? "Unknown Device"),
                          subtitle: Text(device.address ?? ""),
                          trailing: kitchenState.isConnecting &&
                                  kitchenState.selectedDevice?.address ==
                                      device.address
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppStyle.primary,
                                  ),
                                  onPressed: kitchenState.selectedPrinterId ==
                                          null
                                      ? null
                                      : () => kitchenNotifier.connect(device),
                                  child: const Text("Connect"),
                                ),
                        );
                      },
                    ),
                  if (kitchenState.error != null)
                    Padding(
                      padding: EdgeInsets.only(top: 20.r),
                      child: Text(
                        kitchenState.error!,
                        style: TextStyle(color: Colors.red, fontSize: 14.sp),
                      ),
                    ),
                ],
              ),
            ),
            16.verticalSpace,
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                color: AppStyle.white,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Developer / Testing',
                    style: GoogleFonts.inter(
                        fontSize: 18.sp, fontWeight: FontWeight.w600),
                  ),
                  8.verticalSpace,
                  SwitchListTile(
                    title: Text(
                      'Use Order Hooks (new calculation path)',
                      style: GoogleFonts.inter(fontSize: 15.sp),
                    ),
                    subtitle: Text(
                      'Toggle to compare old vs new order calculation logic',
                      style: GoogleFonts.inter(
                          fontSize: 13.sp, color: Colors.grey[600]),
                    ),
                    value: LocalStorage.getUseOrderHooks(),
                    activeColor: AppStyle.primary,
                    onChanged: (v) async {
                      await LocalStorage.setUseOrderHooks(v);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _selectedCategoryTitles({
    required List<CategoryData> categories,
    required List<int> selectedIds,
  }) {
    final selectedSet = selectedIds.toSet();
    return categories
        .where((c) => c.id != null && selectedSet.contains(c.id))
        .map((c) => c.translation?.title ?? 'Unknown')
        .toList();
  }

  Future<void> _showCategoryMultiSelectDialog({
    required BuildContext context,
    required List<CategoryData> allCategories,
    required List<int> initialSelected,
    required ValueChanged<List<int>> onSave,
  }) async {
    final initial = initialSelected.toSet();
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (context) {
        final temp = Set<int>.from(initial);
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Select Categories"),
              content: SizedBox(
                width: 520,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allCategories.length,
                  itemBuilder: (context, index) {
                    final category = allCategories[index];
                    final id = category.id;
                    if (id == null) return const SizedBox.shrink();
                    final title = category.translation?.title ?? 'Unknown';
                    final isChecked = temp.contains(id);
                    return CheckboxListTile(
                      value: isChecked,
                      title: Text(title),
                      activeColor: AppStyle.primary,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            temp.add(id);
                          } else {
                            temp.remove(id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppStyle.primary,
                  ),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(temp),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyle.primary,
                  ),
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      onSave(result.toList()..sort());
    }
  }
}
