
import 'dart:async';
import 'dart:developer' as dartLog;

void printFromSocket(String tag, data) {
  print("=== From socket tag=$tag data=$data");
}

void printFromPeerConnection(String tag, data) {
  print("=== From peer connection tag=$tag data=$data");
}

void log(
String message, {
  DateTime? time,
  int? sequenceNumber,
  int level = 0,
  String name = '',
  Zone? zone,
  Object? error,
  StackTrace? stackTrace,
}) => dartLog.log(
    "((${DateTime.now().millisecondsSinceEpoch})) === $message",
    time: time, sequenceNumber: sequenceNumber, level: level, name: name, zone: zone, error: error, stackTrace: stackTrace);