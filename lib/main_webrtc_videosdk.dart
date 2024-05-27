import 'dart:math';

import 'package:cob_duplication_flutter_webrtc/lib2/communication/const.dart';
import 'package:cob_duplication_flutter_webrtc/src/screens/join_screen.dart';
import 'package:cob_duplication_flutter_webrtc/src/services/signalling_service.dart';
import 'package:flutter/material.dart';

void main() {
  // start videoCall app
  runApp(VideoCallApp());
}

class VideoCallApp extends StatelessWidget {
  VideoCallApp({super.key});

  // generate callerID of local user
  final String selfCallerID =
  Random().nextInt(999999).toString().padLeft(6, '0');

  @override
  Widget build(BuildContext context) {
    // init signalling service
    SignallingService.instance.init(
      websocketUrl: Consts.websocketUrl,
      selfCallerID: selfCallerID,
    );

    // return material app
    return MaterialApp(
      darkTheme: ThemeData.dark().copyWith(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(),
      ),
      themeMode: ThemeMode.dark,
      home: JoinScreen(initialClientId: selfCallerID),
    );
  }
}