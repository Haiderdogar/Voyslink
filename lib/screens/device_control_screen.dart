import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';  // ADD THIS IMPORT
import 'package:voyslink/models/ble_device.dart';
import 'package:voyslink/services/ble_service.dart';
import 'package:voyslink/services/storage_service.dart';
import 'package:voyslink/screens/audio_messages_screen.dart';


class DeviceControlScreen extends StatefulWidget {
  final BleDevice device;
  final BleService bleService;

  const DeviceControlScreen({
    super.key,
    required this.device,
    required this.bleService,
  });

  @override
  State<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  final StorageService _storage = StorageService();
  final TextEditingController _nameController = TextEditingController();

  DeviceConnectionState _connectionState = DeviceConnectionState.connecting;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  bool _isRenaming = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.device.name;
    _listenToConnection();
    _discoverServices();
  }

  void _listenToConnection() {
    _connectionSubscription = widget.bleService.connect(widget.device.id).listen(
          (update) {
        if (mounted) {
          setState(() => _connectionState = update.connectionState);
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connection error: $error')),
          );
        }
      },
    );
  }

  Future<void> _discoverServices() async {
    try {
      // This method should exist in BleService
      await widget.bleService.discoverDeviceUuids(widget.device.id);
    } catch (e) {
      print('Service discovery error: $e');
    }
  }

  Future<void> _renameDevice() async {
    if (_nameController.text.isEmpty) return;

    setState(() => _isRenaming = true);

    // Update local storage
    await _storage.saveDevice(
      widget.device.copyWith(name: _nameController.text),
    );

    // Update connected device
    await _storage.saveConnectedDevice(
      widget.device.copyWith(name: _nameController.text),
    );

    setState(() => _isRenaming = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Device renamed')),
    );
  }

  Future<void> _disconnect() async {
    try {
      await widget.bleService.disconnect(widget.device.id);
      await _storage.clearConnectedDevice();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Disconnect error: $e')),
      );
    }
  }

  // NEW: Method to discover and show UUIDs
  Future<void> _discoverAndShowUuids() async {
    try {
      final uuids = await widget.bleService.discoverDeviceUuids(widget.device.id);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discovered UUIDs'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: uuids.entries.map((entry) {
                  return ListTile(
                    title: Text(entry.key),
                    subtitle: Text(entry.value.toString()),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error discovering UUIDs: $e')),
      );
    }
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _connectionState == DeviceConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => _buildSettingsSheet(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status
          Container(
            padding: const EdgeInsets.all(16),
            color: isConnected ? Colors.green[50] : Colors.orange[50],
            child: Row(
              children: [
                Icon(
                  isConnected ? Icons.check_circle : Icons.sync,
                  color: isConnected ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isConnected
                        ? 'Connected to ${widget.device.name}'
                        : 'Connecting...',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (isConnected)
                  ElevatedButton(
                    onPressed: _disconnect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[50],
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Disconnect'),
                  ),
              ],
            ),
          ),

          // Device info
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.bluetooth_connected,
                    size: 80,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.device.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.device.id,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (widget.device.rssi != null)
                    Text('Signal: ${widget.device.rssi} dBm'),
                  const SizedBox(height: 32),

                  // Next button
                  if (isConnected)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Manage Audio Messages'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AudioMessagesScreen(
                              device: widget.device,
                              bleService: widget.bleService,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSheet() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Device Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Rename device
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Device Name',
              border: const OutlineInputBorder(),
              suffixIcon: _isRenaming
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : IconButton(
                icon: const Icon(Icons.check),
                onPressed: _renameDevice,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Discover UUIDs button
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Discover UUIDs'),
            onTap: () {
              Navigator.pop(context);
              _discoverAndShowUuids();
            },
          ),

          // Device info
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Device ID'),
            subtitle: Text(widget.device.id),
          ),

          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Last Connected'),
            subtitle: Text(
              widget.device.lastConnected?.toString() ?? 'Never',
            ),
          ),

          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}