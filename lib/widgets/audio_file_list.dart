import 'package:flutter/material.dart';
import '../models/audio_models.dart';

class AudioFileList extends StatelessWidget {
  final List<AudioFile> files;
  final int? currentFileIndex;
  final Function(AudioFile) onFileSelect;
  final Function(AudioFile) onFileDelete;
  final bool isLoading;

  const AudioFileList({
    Key? key,
    required this.files,
    this.currentFileIndex,
    required this.onFileSelect,
    required this.onFileDelete,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.audio_file, size: 80, color: Colors.grey[300]),
            SizedBox(height: 20),
            Text(
              'No audio files',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final isCurrent = currentFileIndex == file.index;

        return Card(
          margin: EdgeInsets.only(bottom: 8),
          color: isCurrent ? Colors.blue[50] : null,
          child: ListTile(
            leading: Icon(
              file.isTextMessage ? Icons.message : Icons.audio_file,
              color: isCurrent ? Colors.blue : Colors.grey[700],
            ),
            title: Text(
              file.displayName,
              style: TextStyle(
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!file.isTextMessage)
                  Text('Duration: ${file.formattedDuration}'),
                Text('Size: ${file.fileSize}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!file.isTextMessage)
                  IconButton(
                    icon: Icon(Icons.play_arrow, color: Colors.green),
                    onPressed: () => onFileSelect(file),
                    tooltip: 'Play',
                  ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => onFileDelete(file),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}