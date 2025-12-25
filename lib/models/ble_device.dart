import 'package:flutter/foundation.dart';

@immutable
class BleDevice {
  final String id;
  final String name;
  final int? rssi;
  final List<String> serviceUuids;
  final DateTime lastSeen;
  final DateTime? lastConnected;
  final bool isConnected;

  const BleDevice({
    required this.id,
    required this.name,
    this.rssi,
    this.serviceUuids = const [],
    required this.lastSeen,
    this.lastConnected,
    this.isConnected = false,
  });

  BleDevice copyWith({
    String? id,
    String? name,
    int? rssi,
    List<String>? serviceUuids,
    DateTime? lastSeen,
    DateTime? lastConnected,
    bool? isConnected,
  }) {
    return BleDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      serviceUuids: serviceUuids ?? this.serviceUuids,
      lastSeen: lastSeen ?? this.lastSeen,
      lastConnected: lastConnected ?? this.lastConnected,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'rssi': rssi,
      'serviceUuids': serviceUuids,
      'lastSeen': lastSeen.toIso8601String(),
      'lastConnected': lastConnected?.toIso8601String(),
    };
  }

  factory BleDevice.fromMap(Map<String, dynamic> map) {
    return BleDevice(
      id: map['id'],
      name: map['name'],
      rssi: map['rssi'],
      serviceUuids: List<String>.from(map['serviceUuids']),
      lastSeen: DateTime.parse(map['lastSeen']),
      lastConnected: map['lastConnected'] != null
          ? DateTime.parse(map['lastConnected'])
          : null,
      isConnected: false,
    );
  }
}