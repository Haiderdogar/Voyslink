import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:voyslink/services/permissions.dart';
import 'package:voyslink/screens/device_details_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  // Bluetooth state
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  bool _isScanning = false;
  bool _isLoading = true;
  String _status = 'Initializing...';

  // Device lists
  final List<ScanResult> _scanResults = [];
  final List<BluetoothDevice> _connectedDevices = [];

  // Subscriptions
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }

  Future<void> _initializeBluetooth() async {
    try {
      setState(() => _status = 'Checking Bluetooth support...');

      // Check if Bluetooth is supported
      if (await FlutterBluePlus.isSupported == false) {
        setState(() {
          _status = 'Bluetooth not supported by this device';
          _isLoading = false;
        });
        return;
      }

      // Request permissions
      final hasPermissions = await PermissionUtils.requestBluetoothPermissions();
      if (!hasPermissions) {
        setState(() {
          _status = 'Bluetooth permissions required';
          _isLoading = false;
        });
        return;
      }

      // Listen to adapter state
      _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
        if (mounted) {
          setState(() {
            _adapterState = state;
            _updateStatusFromState(state);
          });
        }
      });

      // Get current state immediately
      try {
        // Use the adapterState stream to get current state
        final currentState = await FlutterBluePlus.adapterState.first;
        setState(() {
          _adapterState = currentState;
          _updateStatusFromState(currentState);
        });
      } catch (e) {
        print('Error getting initial state: $e');
        // Default to checking state
        setState(() => _status = 'Checking Bluetooth state...');
      }

      // Get connected devices
      try {
        _connectedDevices.addAll(FlutterBluePlus.connectedDevices);
      } catch (e) {
        print('Error getting connected devices: $e');
      }

      setState(() => _isLoading = false);

    } catch (e) {
      print('Initialization error: $e');
      setState(() {
        _status = 'Error: ${e.toString().split('\n').first}';
        _isLoading = false;
      });
    }
  }

  void _updateStatusFromState(BluetoothAdapterState state) {
    switch (state) {
      case BluetoothAdapterState.on:
        _status = 'Bluetooth is ON';
        break;
      case BluetoothAdapterState.off:
        _status = 'Bluetooth is OFF';
        break;
      case BluetoothAdapterState.unauthorized:
        _status = 'Bluetooth permission required';
        break;
      case BluetoothAdapterState.unknown:
        _status = 'Checking Bluetooth...';
        break;
      default:
        _status = 'Unknown state';
    }
  }

  Future<void> _turnOnBluetooth() async {
    try {
      // For Android, we can try to turn on Bluetooth
      await FlutterBluePlus.turnOn();

      // Wait a bit and check state
      await Future.delayed(const Duration(seconds: 2));

      // Force a state check
      if (mounted) {
        final state = await FlutterBluePlus.adapterState.first;
        setState(() {
          _adapterState = state;
          _updateStatusFromState(state);
        });
      }

    } catch (e) {
      print('Error turning on Bluetooth: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot turn on Bluetooth: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startScan() async {
    if (_isScanning || _adapterState != BluetoothAdapterState.on) return;

    try {
      setState(() {
        _isScanning = true;
        _status = 'Scanning for devices...';
        _scanResults.clear();
      });

      // Listen to scan results
      _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (mounted) {
          setState(() {
            // Update existing results and add new ones
            for (var result in results) {
              final index = _scanResults.indexWhere((r) => r.device.remoteId == result.device.remoteId);
              if (index >= 0) {
                _scanResults[index] = result;
              } else {
                _scanResults.add(result);
              }
            }
          });
        }
      }, onError: (e) {
        print('Scan error: $e');
        setState(() => _status = 'Scan error: $e');
      });

      // Cancel subscription when scanning stops
      FlutterBluePlus.cancelWhenScanComplete(_scanResultsSubscription!);

      // Start scanning with timeout
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );

      // Wait for scanning to complete
      await FlutterBluePlus.isScanning.where((val) => val == false).first;

      setState(() {
        _isScanning = false;
        _status = 'Scan complete. Found ${_scanResults.length} device(s)';
      });

    } catch (e) {
      print('Start scan error: $e');
      setState(() {
        _isScanning = false;
        _status = 'Scan failed: ${e.toString().split('\n').first}';
      });
    }
  }

  void _stopScan() {
    if (!_isScanning) return;

    try {
      FlutterBluePlus.stopScan();
      _scanResultsSubscription?.cancel();
      setState(() {
        _isScanning = false;
        _status = 'Scan stopped';
      });
    } catch (e) {
      print('Stop scan error: $e');
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      setState(() => _status = 'Connecting to ${device.platformName}...');

      // Connect to device with license parameter
      await device.connect(
        license: License.free,
      );

      // Wait for connection
      await device.connectionState
          .where((state) => state == BluetoothConnectionState.connected)
          .first;

      // Navigate to device details screen
      _navigateToDeviceDetails(device);

    } catch (e) {
      print('Connection error: $e');
      setState(() => _status = 'Connection failed');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect: ${e.toString().split('\n').first}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _navigateToDeviceDetails(BluetoothDevice device) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceDetailsScreen(device: device),
      ),
    );
  }

  Future<void> _checkBluetoothState() async {
    try {
      setState(() => _status = 'Checking Bluetooth state...');

      // Force a check of the current state
      final state = await FlutterBluePlus.adapterState.first;
      setState(() {
        _adapterState = state;
        _updateStatusFromState(state);
      });

    } catch (e) {
      print('Error checking Bluetooth state: $e');
      setState(() => _status = 'Error checking Bluetooth');
    }
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    _stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Scanner'),
        backgroundColor: Colors.blue[800],
        actions: [
          if (_adapterState == BluetoothAdapterState.on)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _checkBluetoothState,
              tooltip: 'Refresh Bluetooth State',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    return Column(
      children: [
        // Status header
        Container(
          padding: const EdgeInsets.all(16),
          color: _getStatusColor(),
          child: Row(
            children: [
              Icon(
                _getStatusIcon(),
                color: _getStatusIconColor(),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusTitle(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_status),
                  ],
                ),
              ),
              if (_isScanning)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
            ],
          ),
        ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Bluetooth toggle button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(_adapterState == BluetoothAdapterState.on
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled),
                  label: Text(_adapterState == BluetoothAdapterState.on
                      ? 'Bluetooth is ON'
                      : 'Turn On Bluetooth'),
                  onPressed: _adapterState == BluetoothAdapterState.on
                      ? null
                      : _turnOnBluetooth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _adapterState == BluetoothAdapterState.on
                        ? Colors.green
                        : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Scan button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(_isScanning ? Icons.stop : Icons.search),
                  label: Text(_isScanning ? 'Stop Scan' : 'Start Scan'),
                  onPressed: _adapterState == BluetoothAdapterState.on
                      ? (_isScanning ? _stopScan : _startScan)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isScanning ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Connected devices section
        if (_connectedDevices.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.bluetooth_connected, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Connected Devices (${_connectedDevices.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ..._connectedDevices.map((device) => _buildDeviceCard(device, isConnected: true)),
          const SizedBox(height: 16),
        ],

        // Scan results section
        Expanded(
          child: _scanResults.isEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.devices,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isScanning ? 'Scanning...' : 'No devices found',
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (!_isScanning && _adapterState == BluetoothAdapterState.on)
                    const SizedBox(height: 10),
                  if (!_isScanning && _adapterState == BluetoothAdapterState.on)
                    const Text(
                      'Tap "Start Scan" to search for devices',
                      style: TextStyle(color: Colors.grey),
                    ),
                  if (_adapterState != BluetoothAdapterState.on)
                    const SizedBox(height: 10),
                  if (_adapterState != BluetoothAdapterState.on)
                    const Text(
                      'Turn on Bluetooth to start scanning',
                      style: TextStyle(color: Colors.orange),
                    ),
                ],
              ),
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _scanResults.length,
            itemBuilder: (context, index) {
              return _buildDeviceCard(_scanResults[index].device);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(_status),
          const SizedBox(height: 10),
          const Text(
            'Please wait...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(BluetoothDevice device, {bool isConnected = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(
          isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
          color: isConnected ? Colors.green : Colors.blue,
        ),
        title: Text(
          device.platformName.isEmpty ? 'Unknown Device' : device.platformName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              device.remoteId.str,
              style: const TextStyle(fontSize: 12),
            ),
            if (isConnected)
              const Text(
                'Connected',
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
          ],
        ),
        trailing: isConnected
            ? const Icon(Icons.check_circle, color: Colors.green)
            : ElevatedButton(
          onPressed: () => _connectToDevice(device),
          child: const Text('Connect'),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_adapterState) {
      case BluetoothAdapterState.on:
        return Colors.green[50]!;
      case BluetoothAdapterState.off:
        return Colors.orange[50]!;
      case BluetoothAdapterState.unauthorized:
        return Colors.red[50]!;
      default:
        return Colors.grey[50]!;
    }
  }

  IconData _getStatusIcon() {
    switch (_adapterState) {
      case BluetoothAdapterState.on:
        return Icons.bluetooth_connected;
      case BluetoothAdapterState.off:
        return Icons.bluetooth_disabled;
      case BluetoothAdapterState.unauthorized:
        return Icons.error;
      default:
        return Icons.bluetooth;
    }
  }

  Color _getStatusIconColor() {
    switch (_adapterState) {
      case BluetoothAdapterState.on:
        return Colors.green;
      case BluetoothAdapterState.off:
        return Colors.orange;
      case BluetoothAdapterState.unauthorized:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusTitle() {
    switch (_adapterState) {
      case BluetoothAdapterState.on:
        return 'Bluetooth is ON';
      case BluetoothAdapterState.off:
        return 'Bluetooth is OFF';
      case BluetoothAdapterState.unauthorized:
        return 'Permission Required';
      default:
        return 'Checking Bluetooth...';
    }
  }
}