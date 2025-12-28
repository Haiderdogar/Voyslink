import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  static Future<bool> requestBluetoothPermissions() async {
    // Check for Android 12+ permissions
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ];

    // Add location permission for Android 6-11
    if (!await _isAndroid12OrAbove()) {
      permissions.add(Permission.locationWhenInUse);
    }

    // Add notification permission for Android 13+
    if (await _isAndroid13OrAbove()) {
      permissions.add(Permission.notification);
    }

    // Add storage permissions if needed
    permissions.add(Permission.storage);

    final Map<Permission, PermissionStatus> statuses = await permissions.request();

    return statuses.values.every((status) => status.isGranted);
  }

  static Future<bool> _isAndroid12OrAbove() async {
    // Check Android version logic
    // You can use device_info_plus package for this
    return false; // Implement based on your needs
  }

  static Future<bool> _isAndroid13OrAbove() async {
    // Check Android version logic
    return false; // Implement based on your needs
  }

  static Future<bool> checkBluetoothPermissions() async {
    return await Permission.bluetooth.isGranted &&
        await Permission.bluetoothConnect.isGranted &&
        await Permission.bluetoothScan.isGranted &&
        await Permission.locationWhenInUse.isGranted;
  }
}