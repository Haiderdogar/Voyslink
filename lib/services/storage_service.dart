import 'package:shared_preferences/shared_preferences.dart';
import 'package:voyslink/models/ble_device.dart';
import 'package:voyslink/models/audio_message.dart';
import 'dart:convert';

class StorageService {
  static const String _devicesKey = 'ble_devices';
  static const String _messagesKey = 'audio_messages_';
  static const String _connectedDeviceKey = 'connected_device';

  Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  // Save connected device
  Future<void> saveConnectedDevice(BleDevice device) async {
    final prefs = await _prefs;
    await prefs.setString(_connectedDeviceKey, json.encode(device.toMap()));
  }

  // Get connected device
  Future<BleDevice?> getConnectedDevice() async {
    final prefs = await _prefs;
    final data = prefs.getString(_connectedDeviceKey);
    if (data == null) return null;
    return BleDevice.fromMap(json.decode(data));
  }

  // Save discovered devices
  Future<void> saveDevice(BleDevice device) async {
    final prefs = await _prefs;
    final devices = await getDevices();

    // Remove if exists
    devices.removeWhere((d) => d.id == device.id);

    // Add at beginning
    devices.insert(0, device.copyWith(lastSeen: DateTime.now()));

    // Keep only last 10 devices
    if (devices.length > 10) {
      devices.removeRange(10, devices.length);
    }

    await prefs.setString(
        _devicesKey,
        json.encode(devices.map((d) => d.toMap()).toList())
    );
  }

  // Get all saved devices
  Future<List<BleDevice>> getDevices() async {
    final prefs = await _prefs;
    final data = prefs.getString(_devicesKey);
    if (data == null) return [];

    final List<dynamic> list = json.decode(data);
    return list.map((e) => BleDevice.fromMap(e)).toList();
  }

  // Save audio messages for a device
  Future<void> saveMessages(String deviceId, List<AudioMessage> messages) async {
    final prefs = await _prefs;
    final key = '$_messagesKey$deviceId';

    await prefs.setString(
        key,
        json.encode(messages.map((m) => m.toMap()).toList())
    );
  }

  // Get audio messages for a device
  Future<List<AudioMessage>> getMessages(String deviceId) async {
    final prefs = await _prefs;
    final key = '$_messagesKey$deviceId';
    final data = prefs.getString(key);

    if (data == null) return [];

    final List<dynamic> list = json.decode(data);
    return list.map((e) => AudioMessage.fromMap(e)).toList();
  }

  // Clear connected device
  Future<void> clearConnectedDevice() async {
    final prefs = await _prefs;
    await prefs.remove(_connectedDeviceKey);
  }
}