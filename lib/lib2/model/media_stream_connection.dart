import 'package:flutter_webrtc/flutter_webrtc.dart';

class MediaStreamConnection {
  final String peerId;
  final MediaStream mediaStream;

  MediaStreamConnection({
    required this.peerId,
    required this.mediaStream,
  });
}