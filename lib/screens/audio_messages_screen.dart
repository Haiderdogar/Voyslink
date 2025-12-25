import 'dart:async';
import 'package:flutter/material.dart';
import 'package:voyslink/models/ble_device.dart';
import 'package:voyslink/models/audio_message.dart';
import 'package:voyslink/services/ble_service.dart';
import 'package:voyslink/services/storage_service.dart';

class AudioMessagesScreen extends StatefulWidget {
  final BleDevice device;
  final BleService bleService;

  const AudioMessagesScreen({
    super.key,
    required this.device,
    required this.bleService,
  });

  @override
  State<AudioMessagesScreen> createState() => _AudioMessagesScreenState();
}

class _AudioMessagesScreenState extends State<AudioMessagesScreen> {
  final StorageService _storage = StorageService();
  final TextEditingController _messageController = TextEditingController();

  List<AudioMessage> _messages = [];
  bool _isLoading = true;
  bool _isPlaying = false;
  int? _currentlyPlayingIndex;
  String _status = 'Loading messages...';
  Timer? _refreshTimer;
  StreamSubscription<List<int>>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _loadMessagesFromDevice();
    _setupAutoRefresh();
  }

  // Load messages directly from BLE device
  Future<void> _loadMessagesFromDevice() async {
    setState(() {
      _isLoading = true;
      _status = 'Reading messages from device...';
    });

    try {
      // Read messages directly from BLE device
      final deviceMessages = await widget.bleService.readAllMessages(widget.device.id);

      // Convert to AudioMessage objects
      final List<AudioMessage> loadedMessages = [];
      for (int i = 0; i < deviceMessages.length; i++) {
        if (i < 5 && deviceMessages[i].isNotEmpty) {
          loadedMessages.add(AudioMessage(
            id: '${widget.device.id}_${i + 1}',
            text: deviceMessages[i],
            createdAt: DateTime.now(),
            index: i + 1, // Slots 1-5
          ));
        }
      }

      if (mounted) {
        setState(() {
          _messages = loadedMessages;
          _isLoading = false;
          _status = loadedMessages.isEmpty
              ? 'No messages found on device'
              : 'Loaded ${loadedMessages.length} messages';
        });

        // Save to local storage for offline reference
        await _storage.saveMessages(widget.device.id, loadedMessages);
      }

      // Subscribe to real-time updates if available
      _setupMessageSubscription();

    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _status = 'Error reading messages: $e';
        });

        // Try to load from local storage as fallback
        final stored = await _storage.getMessages(widget.device.id);
        if (stored.isNotEmpty) {
          setState(() {
            _messages = stored;
            _status = 'Loaded ${stored.length} messages from cache';
          });
        }
      }
    }
  }

  void _setupMessageSubscription() {
    _messageSubscription?.cancel();

    _messageSubscription = widget.bleService.subscribeToMessages().listen((data) {
      if (data.isNotEmpty) {
        // Parse new data
        final message = String.fromCharCodes(data);
        print('Real-time update: $message');

        // Handle real-time updates (e.g., playback status)
        if (message.startsWith('PLAYING:')) {
          final slot = int.tryParse(message.substring(8));
          if (slot != null && mounted) {
            setState(() {
              _isPlaying = true;
              _currentlyPlayingIndex = slot;
            });
          }
        } else if (message == 'STOPPED' && mounted) {
          setState(() {
            _isPlaying = false;
            _currentlyPlayingIndex = null;
          });
        }
      }
    }, onError: (error) {
      print('Message subscription error: $error');
    });
  }

  void _setupAutoRefresh() {
    // Refresh messages every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!_isLoading) {
        _loadMessagesFromDevice();
      }
    });
  }

  Future<void> _addMessage() async {
    if (_messageController.text.isEmpty) return;

    final newMessage = _messageController.text;

    // Find available slot (1-5)
    int availableSlot = 1;
    final usedSlots = _messages.map((m) => m.index).toList();

    for (int i = 1; i <= 5; i++) {
      if (!usedSlots.contains(i)) {
        availableSlot = i;
        break;
      }
    }

    // If all slots full, replace the oldest (slot 5)
    if (availableSlot > 5) {
      availableSlot = 5;
      // Remove message from slot 5
      await widget.bleService.deleteMessage(5);
    }

    try {
      // Write to BLE device
      await widget.bleService.writeMessage(newMessage, availableSlot);

      // Create message object
      final message = AudioMessage(
        id: '${widget.device.id}_${DateTime.now().millisecondsSinceEpoch}',
        text: newMessage,
        createdAt: DateTime.now(),
        index: availableSlot,
      );

      // Update local list - remove if slot already exists
      setState(() {
        _messages.removeWhere((m) => m.index == availableSlot);
        _messages.insert(0, message);

        // Keep only 5 messages
        if (_messages.length > 5) {
          _messages.removeRange(5, _messages.length);
        }
      });

      // Save to storage
      await _storage.saveMessages(widget.device.id, _messages);

      // Clear input
      _messageController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message added to slot $availableSlot')),
      );

      // Refresh to get updated list
      _loadMessagesFromDevice();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding message: $e')),
      );
    }
  }

  Future<void> _playMessage(int slot) async {
    try {
      setState(() {
        _isPlaying = true;
        _currentlyPlayingIndex = slot;
      });

      await widget.bleService.playMessage(slot);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Playing message from slot $slot')),
      );

    } catch (e) {
      setState(() {
        _isPlaying = false;
        _currentlyPlayingIndex = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing message: $e')),
      );
    }
  }

  Future<void> _stopPlayback() async {
    try {
      await widget.bleService.stopPlayback();

      setState(() {
        _isPlaying = false;
        _currentlyPlayingIndex = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playback stopped')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error stopping playback: $e')),
      );
    }
  }

  Future<void> _deleteMessage(int slot) async {
    try {
      await widget.bleService.deleteMessage(slot);

      setState(() {
        _messages.removeWhere((m) => m.index == slot);
      });

      // Save updated list
      await _storage.saveMessages(widget.device.id, _messages);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message deleted from slot $slot')),
      );

      // Refresh to get updated list
      _loadMessagesFromDevice();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting message: $e')),
      );
    }
  }

  Future<void> _refreshMessages() async {
    await _loadMessagesFromDevice();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageSubscription?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Messages - ${widget.device.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshMessages,
            tooltip: 'Refresh Messages',
          ),
          if (_isPlaying)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopPlayback,
              tooltip: 'Stop Playback',
            ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_status),
          ],
        ),
      )
          : Column(
        children: [
          // Status bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Row(
              children: [
                const Icon(Icons.info, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(_status)),
                Text('${_messages.length}/5 slots'),
              ],
            ),
          ),

          // Add message section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Add New Message',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _messageController,
                      maxLines: 3,
                      maxLength: 200,
                      decoration: InputDecoration(
                        labelText: 'Message text',
                        border: const OutlineInputBorder(),
                        hintText: 'Enter text to store on BLE device...',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _addMessage,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _messages.length >= 5
                          ? 'Device storage full (5/5). New messages will replace slot 5.'
                          : '${5 - _messages.length} slot(s) available',
                      style: TextStyle(
                        color: _messages.length >= 5 ? Colors.red : Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.volume_up,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text('No messages on device'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _refreshMessages,
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isPlaying = _currentlyPlayingIndex == message.index;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isPlaying ? Colors.green : Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${message.index}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      message.text,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      'Slot ${message.index} • ${_formatDate(message.createdAt)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPlaying)
                          IconButton(
                            icon: const Icon(Icons.stop, color: Colors.red),
                            onPressed: _stopPlayback,
                            tooltip: 'Stop',
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.play_arrow, color: Colors.green),
                            onPressed: () => _playMessage(message.index),
                            tooltip: 'Play',
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.grey),
                          onPressed: () => _deleteMessage(message.index),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}