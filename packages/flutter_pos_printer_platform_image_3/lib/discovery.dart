import 'flutter_pos_printer_platform_image_3.dart';

class PrinterDiscovered<T> {
  String name;
  T detail;
  PrinterDiscovered({
    required this.name,
    required this.detail,
  });
}

typedef DiscoverResult<T> = Future<List<PrinterDiscovered<T>>>;

Future<List<PrinterDiscovered>> discoverPrinters(
    {List<Future<List<PrinterDiscovered>> Function()>? modes}) async {
  final effectiveModes = modes ??
      [
        () async => (await UsbPrinterConnector.discoverPrinters()).cast<PrinterDiscovered>(),
        () async => (await BluetoothPrinterConnector.discoverPrinters()).cast<PrinterDiscovered>(),
        () async => (await TcpPrinterConnector.discoverPrinters()).cast<PrinterDiscovered>(),
      ];
  List<PrinterDiscovered> result = [];
  await Future.wait(effectiveModes.map((m) async {
    result.addAll(await m());
  }));
  return result;
}
