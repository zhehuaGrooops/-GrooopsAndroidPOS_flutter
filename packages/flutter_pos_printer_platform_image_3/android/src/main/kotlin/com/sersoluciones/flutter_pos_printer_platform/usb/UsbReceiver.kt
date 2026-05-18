package com.sersoluciones.flutter_pos_printer_platform.usb

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.util.Log

class UsbReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        val action = intent?.action
        Log.d("UsbReceiver", "Inside USB Broadcast action $action")

        if (context == null || intent == null) return

        if (UsbManager.ACTION_USB_DEVICE_ATTACHED == action) {
            val usbDevice = getUsbDeviceFromIntent(intent) ?: return

            val mPermissionIndent = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                PendingIntent.getBroadcast(
                    context,
                    0,
                    Intent("com.flutter_pos_printer.USB_PERMISSION").setPackage(context.packageName),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                )
            } else {
                PendingIntent.getBroadcast(
                    context,
                    0,
                    Intent("com.flutter_pos_printer.USB_PERMISSION").setPackage(context.packageName),
                    PendingIntent.FLAG_UPDATE_CURRENT
                )
            }
            val mUSBManager = context?.getSystemService(Context.USB_SERVICE) as UsbManager?
            mUSBManager?.requestPermission(usbDevice, mPermissionIndent)

        }
    }

    private fun getUsbDeviceFromIntent(intent: Intent): UsbDevice? {
        @Suppress("DEPRECATION")
        return intent.getParcelableExtra(UsbManager.EXTRA_DEVICE) as? UsbDevice
    }
}
