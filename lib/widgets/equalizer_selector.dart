import 'package:flutter/material.dart';
import '../services/audio_service.dart';

class EqualizerSelector extends StatelessWidget {
  final int currentEq;
  final Function(int) onEqChanged;

  const EqualizerSelector({
    Key? key,
    required this.currentEq,
    required this.onEqChanged,
  }) : super(key: key);

  final Map<int, Map<String, dynamic>> _eqOptions = const {
    AudioService.EQ_NORMAL: {'name': 'Normal', 'icon': Icons.equalizer},
    AudioService.EQ_POP: {'name': 'Pop', 'icon': Icons.music_note},
    AudioService.EQ_ROCK: {'name': 'Rock', 'icon': Icons.rocket_launch},
    AudioService.EQ_JAZZ: {'name': 'Jazz', 'icon': Icons.piano},
    AudioService.EQ_CLASSIC: {'name': 'Classic', 'icon': Icons.theater_comedy},
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
                Icon(Icons.equalizer, size: 20),
                SizedBox(width: 8),
                Text(
                  'Equalizer',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            DropdownButton<int>(
              value: currentEq,
              isExpanded: true,
              onChanged: (value) {
                if (value != null) onEqChanged(value);
              },
              items: _eqOptions.entries.map((entry) {
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