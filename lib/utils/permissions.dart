import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  static Future<bool> requestAll() async {
    final List<Permission> permissions = [];

    if (Platform.isAndroid) {
      permissions.addAll([
        Permission.locationWhenInUse,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ]);
    }

    if (Platform.isIOS) {
      permissions.add(Permission.bluetooth);
      // Note: iOS also needs location permission for BLE scanning
      permissions.add(Permission.locationWhenInUse);
    }

    bool granted = true;

    for (final p in permissions) {
      if (!await p.isGranted) {
        final result = await p.request();
        if (!result.isGranted) granted = false;
      }
    }

    return granted;
  }

  // Check if all required permissions are granted
  static Future<bool> checkAllGranted() async {
    if (Platform.isAndroid) {
      return await Permission.locationWhenInUse.isGranted &&
          await Permission.bluetoothScan.isGranted &&
          await Permission.bluetoothConnect.isGranted;
    } else if (Platform.isIOS) {
      return await Permission.bluetooth.isGranted &&
          await Permission.locationWhenInUse.isGranted;
    }
    return false;
  }
}