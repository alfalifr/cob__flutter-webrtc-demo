import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Represents the identity of connection between 2 devices.
class Session {
  final String peerId;
  final String sessionId;

  const Session({
    required this.peerId,
    required this.sessionId,
  });

  const Session.fromLocalId({
    required this.peerId,
    required String localId,
  }): sessionId = "${localId}_$peerId"
  ;

  @override
  bool operator ==(other) => other is Session && other.sessionId == sessionId;

  @override
  int get hashCode => sessionId.hashCode;

  @override
  String toString() => "Session(sessionId=$sessionId, peerId=$peerId)";
}