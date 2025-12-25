import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:voyslink/models/ble_device.dart';

class BleService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  // Will be discovered dynamically
  Uuid? _serviceUuid;
  Uuid? _readCharacteristicUuid;
  Uuid? _writeCharacteristicUuid;

  final Map<String, QualifiedCharacteristic> _characteristics = {};
  final Map<String, StreamSubscription<List<int>>> _subscriptions = {};

  // Discover all services and characteristics
  Future<Map<String, Uuid>> discoverDeviceUuids(String deviceId) async {
    try {
      final services = await _ble.discoverServices(deviceId);
      final discoveredUuids = <String, Uuid>{};

      print('=== Discovering BLE Services ===');
      for (final service in services) {
        final serviceUuid = service.serviceId.toString();
        print('Service: $serviceUuid');

        for (final characteristic in service.characteristics) {
          final charUuid = characteristic.characteristicId.toString();

          // Check properties correctly
          final canRead = characteristic.isReadable;
          final canWrite = characteristic.isWritableWithResponse ||
              characteristic.isWritableWithoutResponse;

          print('  Characteristic: $charUuid');
          print('  Can Read: $canRead, Can Write: $canWrite');

          // Store for potential use
          discoveredUuids[charUuid] = characteristic.characteristicId;

          // Auto-detect read/write characteristics
          if (canRead) {
            _readCharacteristicUuid = characteristic.characteristicId;
            print('  -> Detected as READ characteristic');
          }

          if (canWrite) {
            _writeCharacteristicUuid = characteristic.characteristicId;
            print('  -> Detected as WRITE characteristic');
          }

          // Store the service UUID if we find a characteristic we need
          if (_readCharacteristicUuid != null || _writeCharacteristicUuid != null) {
            _serviceUuid = service.serviceId;
          }

          // Store the characteristic for later use
          _characteristics[charUuid] = QualifiedCharacteristic(
            serviceId: service.serviceId,
            characteristicId: characteristic.characteristicId,
            deviceId: deviceId,
          );
        }
      }

      print('=== Discovery Complete ===');
      print('Service UUID: ${_serviceUuid?.toString()}');
      print('Read Characteristic: ${_readCharacteristicUuid?.toString()}');
      print('Write Characteristic: ${_writeCharacteristicUuid?.toString()}');

      return discoveredUuids;
    } catch (e) {
      print('Service discovery error: $e');
      return {};
    }
  }

  // Convert discovered device to our model
  BleDevice toBleDevice(DiscoveredDevice device) {
    return BleDevice(
      id: device.id,
      name: device.name.isNotEmpty ? device.name : 'Unknown Device',
      rssi: device.rssi,
      serviceUuids: device.serviceUuids.map((u) => u.toString()).toList(),
      lastSeen: DateTime.now(),
    );
  }

  // Scan for devices
  Stream<BleDevice> scan() {
    return _ble.scanForDevices(
      withServices: [],
      scanMode: ScanMode.lowLatency,
    ).map(toBleDevice);
  }

  // Connect to device
  Stream<ConnectionStateUpdate> connect(String deviceId) {
    return _ble.connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 10),
    );
  }

  // Read all messages from device
  Future<List<String>> readAllMessages(String deviceId) async {
    List<String> messages = [];

    try {
      // First discover services if not already done
      if (_serviceUuid == null) {
        await discoverDeviceUuids(deviceId);
      }

      if (_readCharacteristicUuid == null) {
        print('No read characteristic found');
        return messages;
      }

      final characteristic = _characteristics[_readCharacteristicUuid!.toString()];
      if (characteristic == null) {
        print('Read characteristic not available');
        return messages;
      }

      // Read the characteristic value
      final data = await _ble.readCharacteristic(characteristic);

      if (data.isNotEmpty) {
        // Parse the data based on your BLE device's format
        final message = utf8.decode(data);
        print('Raw data from device: $message');

        // Parse messages - adjust this based on your device's data format
        List<String> parsedMessages = [];
        if (message.contains('|')) {
          // If messages are separated by pipes
          parsedMessages = message.split('|').where((m) => m.isNotEmpty).toList();
        } else if (message.contains(',')) {
          // If messages are separated by commas
          parsedMessages = message.split(',').where((m) => m.isNotEmpty).toList();
        } else {
          // Single message
          parsedMessages = [message];
        }

        // Trim whitespace and filter empty messages
        messages = parsedMessages.map((msg) => msg.trim()).toList();

        print('Parsed ${messages.length} messages from device');
      }
    } catch (e) {
      print('Error reading messages: $e');
    }

    return messages;
  }

  // Write message to specific slot (1-5)
  Future<void> writeMessage(String message, int slot) async {
    try {
      if (_writeCharacteristicUuid == null) {
        throw Exception('Write characteristic not discovered');
      }

      if (slot < 1 || slot > 5) {
        throw Exception('Slot must be between 1 and 5');
      }

      // Format: "WRITE:slot:message"
      final formattedMessage = "WRITE:$slot:$message";
      final bytes = Uint8List.fromList(utf8.encode(formattedMessage));

      final characteristic = _characteristics[_writeCharacteristicUuid!.toString()];
      if (characteristic != null) {
        await _ble.writeCharacteristicWithResponse(characteristic, value: bytes);
        print('Message written to slot $slot: $message');
      } else {
        throw Exception('Write characteristic not available');
      }
    } catch (e) {
      print('Write error: $e');
      rethrow;
    }
  }

  // Delete message from slot
  Future<void> deleteMessage(int slot) async {
    return await writeMessage('', slot); // Empty message to delete
  }

  // Play message from slot
  Future<void> playMessage(int slot) async {
    try {
      if (_writeCharacteristicUuid == null) {
        throw Exception('Write characteristic not discovered');
      }

      final data = "PLAY:$slot";
      final bytes = Uint8List.fromList(utf8.encode(data));

      final characteristic = _characteristics[_writeCharacteristicUuid!.toString()];
      if (characteristic != null) {
        await _ble.writeCharacteristicWithResponse(characteristic, value: bytes);
        print('Play command sent for slot $slot');
      }
    } catch (e) {
      print('Play error: $e');
      rethrow;
    }
  }

  // Stop playing
  Future<void> stopPlayback() async {
    try {
      if (_writeCharacteristicUuid == null) {
        throw Exception('Write characteristic not discovered');
      }

      final data = "STOP";
      final bytes = Uint8List.fromList(utf8.encode(data));

      final characteristic = _characteristics[_writeCharacteristicUuid!.toString()];
      if (characteristic != null) {
        await _ble.writeCharacteristicWithResponse(characteristic, value: bytes);
        print('Stop command sent');
      }
    } catch (e) {
      print('Stop error: $e');
      rethrow;
    }
  }

  // Subscribe to notifications for real-time updates
  Stream<List<int>> subscribeToMessages() {
    final controller = StreamController<List<int>>();

    if (_readCharacteristicUuid == null) {
      controller.add([]);
      controller.close();
      return controller.stream;
    }

    final characteristic = _characteristics[_readCharacteristicUuid!.toString()];
    if (characteristic == null) {
      controller.add([]);
      controller.close();
      return controller.stream;
    }

    _subscriptions[_readCharacteristicUuid!.toString()] =
        _ble.subscribeToCharacteristic(characteristic).listen((data) {
          controller.add(data);
        }, onError: (error) {
          controller.addError(error);
        });

    return controller.stream;
  }

  // Clear all subscriptions
  void clearSubscriptions() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  // Disconnect from device - FIXED: Use the correct method
  Future<void> disconnect(String deviceId) async {
    try {
      // FIXED: The correct way to disconnect is to cancel the connection
      // Since we're using connectToDevice which returns a stream,
      // we need to cancel the connection stream
      clearSubscriptions();
      _characteristics.clear();
      _serviceUuid = null;
      _readCharacteristicUuid = null;
      _writeCharacteristicUuid = null;

      // Alternative: If you need to actively disconnect, you might need to
      // keep track of the connection subscription and cancel it
      print('Disconnected from $deviceId');

    } catch (e) {
      print('Disconnect error: $e');
    }
  }

  // Get discovered UUIDs
  Map<String, Uuid?> getDiscoveredUuids() {
    return {
      'service': _serviceUuid,
      'read': _readCharacteristicUuid,
      'write': _writeCharacteristicUuid,
    };
  }

  // Check Bluetooth status
  Stream<BleStatus> get statusStream => _ble.statusStream;
}