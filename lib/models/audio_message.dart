import 'package:flutter/foundation.dart';

@immutable
class AudioMessage {
  final String id;
  final String text;
  final DateTime createdAt;
  final int index; // 1-5 for storage position

  const AudioMessage({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.index,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'index': index,
    };
  }

  factory AudioMessage.fromMap(Map<String, dynamic> map) {
    return AudioMessage(
      id: map['id'],
      text: map['text'],
      createdAt: DateTime.parse(map['createdAt']),
      index: map['index'],
    );
  }
}