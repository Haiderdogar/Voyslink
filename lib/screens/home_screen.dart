import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:voyslink/utils/permissions.dart';
import 'package:voyslink/models/ble_device.dart';
import 'package:voyslink/services/storage_service.dart';
import 'package:voyslink/screens/scan_devices_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final StorageService _storage = StorageService();
  BleStatus _status = BleStatus.unknown;
  BleDevice? _lastConnectedDevice;  // Now this type is recognized

  @override
  void initState() {
    super.initState();
    _initBluetooth();
    _loadLastConnected();
  }

  Future<void> _loadLastConnected() async {
    final device = await _storage.getConnectedDevice();
    if (device != null && mounted) {
      setState(() => _lastConnectedDevice = device);
    }
  }

  Future<void> _initBluetooth() async {
    // Request all permissions first
    await PermissionUtils.requestAll();

    // For iOS: Trigger BLE permission popup
    if (Platform.isIOS) {
      try {
        final dummyStream = _ble.scanForDevices(
          withServices: [],
          scanMode: ScanMode.lowLatency,
        ).listen((_) {});

        await Future.delayed(const Duration(milliseconds: 100));
        dummyStream.cancel();
      } catch (e) {
        print('BLE permission trigger error: $e');
      }
    }

    // Listen to Bluetooth status
    _ble.statusStream.listen((s) {
      if (mounted) {
        setState(() => _status = s);
      }
    });
  }

  Future<void> _openSettingsWithGuidance() async {
    if (Platform.isIOS) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enable Bluetooth Access'),
          content: const Text(
            'To use Bluetooth features on iOS:\n\n'
                '1. Enable Bluetooth in Settings → Bluetooth\n'
                '2. Grant Bluetooth permission to this app\n'
                '3. Return to the app\n\n'
                'Tap "Open Settings" to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    } else {
      await openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOn = _status == BleStatus.ready;

    return Scaffold(
      appBar: AppBar(title: const Text('BLE Audio Controller')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status indicator
            Icon(
              isOn ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              size: 64,
              color: isOn ? Colors.blue : Colors.grey,
            ),
            const SizedBox(height: 20),

            Text(
              isOn ? 'Bluetooth is ON' : 'Bluetooth is OFF',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Last connected device
            if (_lastConnectedDevice != null)
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Last Connected Device',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(_lastConnectedDevice!.name),
                      Text(
                        _lastConnectedDevice!.id,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.bluetooth),
                        label: const Text('Reconnect'),
                        onPressed: isOn ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ScanScreen(
                                autoConnectDeviceId: _lastConnectedDevice!.id,
                              ),
                            ),
                          );
                        } : null,
                      ),
                    ],
                  ),
                ),
              ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (!isOn)
                    ElevatedButton(
                      onPressed: _openSettingsWithGuidance,
                      child: Text(
                        Platform.isIOS
                            ? 'Enable Bluetooth & Permissions'
                            : 'Open Settings to Enable Bluetooth',
                      ),
                    ),

                  if (isOn)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.search),
                      label: const Text('Scan for BLE Devices'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ScanScreen()),
                        );
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
}