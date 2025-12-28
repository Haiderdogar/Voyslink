import 'package:flutter/material.dart';
import '../services/audio_service.dart';

class PlayModeSelector extends StatelessWidget {
  final int currentMode;
  final Function(int) onModeChanged;

  const PlayModeSelector({
    Key? key,
    required this.currentMode,
    required this.onModeChanged,
  }) : super(key: key);

  final Map<int, Map<String, dynamic>> _modeOptions = const {
    AudioService.MODE_SINGLE: {'name': 'Single', 'icon': Icons.play_arrow},
    AudioService.MODE_ALL_CYCLE: {'name': 'All Loop', 'icon': Icons.repeat},
    AudioService.MODE_RANDOM: {'name': 'Random', 'icon': Icons.shuffle},
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.play_circle_filled, size: 20),
                SizedBox(width: 8),
                Text(
                  'Play Mode',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            DropdownButton<int>(
              value: currentMode,
              isExpanded: true,
              onChanged: (value) {
                if (value != null) onModeChanged(value);
              },
              items: _modeOptions.entries.map((entry) {
                return DropdownMenuItem<int>(
                  value: entry.key,
                  child: Row(
                    children: [
                      Icon(entry.value['icon'], size: 20),
                      SizedBox(width: 8),
                      Text(entry.value['name']),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}