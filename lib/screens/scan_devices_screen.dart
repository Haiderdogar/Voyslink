import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';  // ADD THIS IMPORT
import 'package:voyslink/services/ble_service.dart';
import 'package:voyslink/services/storage_service.dart';
import 'package:voyslink/models/ble_device.dart';
import 'package:voyslink/screens/device_control_screen.dart';

class ScanScreen extends StatefulWidget {
  final String? autoConnectDeviceId;

  const ScanScreen({super.key, this.autoConnectDeviceId});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final BleService _bleService = BleService();
  final StorageService _storage = StorageService();

  final List<BleDevice> _devices = [];
  final List<BleDevice> _recentDevices = [];

  StreamSubscription<BleDevice>? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;  // Now recognized

  bool _scanning = false;
  bool _autoConnecting = false;
  String? _currentlyConnectingId;
  String _status = 'Ready to scan';
  Timer? _scanTimer;

  @override
  void initState() {
    super.initState();
    _loadRecentDevices();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScan();
      _tryAutoConnect();
    });
  }

  Future<void> _loadRecentDevices() async {
    final devices = await _storage.getDevices();
    if (mounted) {
      setState(() => _recentDevices.addAll(devices));
    }
  }

  void _tryAutoConnect() {
    if (widget.autoConnectDeviceId != null) {
      final device = _recentDevices.firstWhere(
            (d) => d.id == widget.autoConnectDeviceId,
        orElse: () => _devices.firstWhere(
              (d) => d.id == widget.autoConnectDeviceId,
          orElse: () => BleDevice(
            id: widget.autoConnectDeviceId!,
            name: 'Device',
            lastSeen: DateTime.now(),
            serviceUuids: [],
          ),
        ),
      );

      _connectToDevice(device);
    }
  }

  void _startScan() {
    if (_scanning) return;

    setState(() {
      _scanning = true;
      _status = 'Scanning for devices...';
      _devices.clear();
    });

    _scanSubscription = _bleService.scan().listen(
          (device) {
        if (!_devices.any((d) => d.id == device.id)) {
          setState(() => _devices.add(device));
          _storage.saveDevice(device);
        }
      },
      onError: (error) {
        setState(() {
          _status = 'Scan error: $error';
          _scanning = false;
        });
      },
    );

    // Auto-stop after 30 seconds
    _scanTimer = Timer(const Duration(seconds: 30), _stopScan);
  }

  void _stopScan() {
    _scanSubscription?.cancel();
    _scanTimer?.cancel();

    setState(() {
      _scanning = false;
      _status = _devices.isEmpty
          ? 'No devices found. Tap Retry to scan again.'
          : 'Found ${_devices.length} device(s)';
    });
  }

  void _connectToDevice(BleDevice device) async {
    if (_currentlyConnectingId == device.id) return;

    // Disconnect from previous device if connected
    if (_currentlyConnectingId != null) {
      await _bleService.disconnect(_currentlyConnectingId!);
    }

    setState(() {
      _currentlyConnectingId = device.id;
      _autoConnecting = true;
    });

    _connectionSubscription = _bleService.connect(device.id).listen(
          (update) {
        // FIXED: Use DeviceConnectionState.connected (imported from flutter_reactive_ble)
        if (update.connectionState == DeviceConnectionState.connected) {
          // Save as connected device
          _storage.saveConnectedDevice(device.copyWith(
            lastConnected: DateTime.now(),
            isConnected: true,
          ));

          // Navigate to control screen
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => DeviceControlScreen(
                  device: device,
                  bleService: _bleService,
                ),
              ),
            );
          }
        } else if (update.connectionState == DeviceConnectionState.disconnected) {
          setState(() {
            _currentlyConnectingId = null;
            _autoConnecting = false;
          });
        }
      },
      onError: (error) {
        setState(() {
          _currentlyConnectingId = null;
          _autoConnecting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $error')),
        );
      },
    );
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _scanTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Devices'),
        actions: [
          if (_scanning)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopScan,
              tooltip: 'Stop Scanning',
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _startScan,
              tooltip: 'Start Scanning',
            ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            padding: const EdgeInsets.all(12),
            color: _scanning ? Colors.blue[50] : Colors.grey[100],
            child: Row(
              children: [
                Icon(
                  _scanning ? Icons.search : Icons.info,
                  color: _scanning ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(_status)),
                if (_scanning) const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
          ),

          // Recent devices section
          if (_recentDevices.isNotEmpty && !_scanning)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recently Connected',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _recentDevices.length,
                      itemBuilder: (context, index) {
                        final device = _recentDevices[index];
                        return _buildDeviceCard(device, isRecent: true);
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Device list
          Expanded(
            child: _scanning && _devices.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Searching for BLE devices...'),
                ],
              ),
            )
                : _devices.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.bluetooth_disabled,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(_status),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry Scan'),
                    onPressed: _startScan,
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];
                return _buildDeviceCard(device);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(BleDevice device, {bool isRecent = false}) {
    final isConnecting = _currentlyConnectingId == device.id;
    final isConnected = _currentlyConnectingId == device.id && _autoConnecting;

    return Card(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bluetooth,
                  color: isConnected ? Colors.green : Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    device.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              device.id.substring(0, 17),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            if (device.rssi != null)
              Text(
                'Signal: ${device.rssi} dBm',
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: isConnecting ? null : () => _connectToDevice(device),
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected ? Colors.green : null,
                minimumSize: const Size(100, 36),
              ),
              child: isConnecting
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Text(isConnected ? 'Connected' : 'Connect'),
            ),
          ],
        ),
      ),
    );
  }
}