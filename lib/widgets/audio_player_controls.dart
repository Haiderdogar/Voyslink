import 'package:flutter/material.dart';

class AudioPlayerControls extends StatelessWidget {
  final bool isPlaying;
  final bool isRecording;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;

  const AudioPlayerControls({
    Key? key,
    required this.isPlaying,
    required this.isRecording,
    required this.onPlayPause,
    required this.onStop,
    required this.onNext,
    required this.onPrevious,
    required this.onStartRecording,
    required this.onStopRecording,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Playback Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Previous
                IconButton(
                  icon: Icon(Icons.skip_previous, size: 32),
                  onPressed: onPrevious,
                  tooltip: 'Previous Track',
                ),

                // Stop
                IconButton(
                  icon: Icon(Icons.stop, size: 32),
                  onPressed: onStop,
                  tooltip: 'Stop',
                  color: Colors.red,
                ),

                // Play/Pause
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPlaying ? Colors.red : Colors.green,
                  ),
                  child: IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 40,
                      color: Colors.white,
                    ),
                    onPressed: onPlayPause,
                    tooltip: isPlaying ? 'Pause' : 'Play',
                  ),
                ),

                // Next
                IconButton(
                  icon: Icon(Icons.skip_next, size: 32),
                  onPressed: onNext,
                  tooltip: 'Next Track',
                ),
              ],
            ),

            SizedBox(height: 16),

            // Recording Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(isRecording ? Icons.stop : Icons.mic),
                    label: Text(isRecording ? 'Stop Recording' : 'Start Recording'),
                    onPressed: isRecording ? onStopRecording : onStartRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRecording ? Colors.red : Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}