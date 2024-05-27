import 'dart:math';

import 'package:cob_duplication_flutter_webrtc/lib2/communication/realtime/webrtc/webrtc_connection.dart';
import 'package:cob_duplication_flutter_webrtc/src/utils/prints.dart';
import 'package:flutter/material.dart';
import '../../lib2/communication/const.dart';
import '../services/signalling_service.dart';
import 'call_screen.dart';
import 'call_screen_2.dart';

class JoinScreen extends StatefulWidget {

  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  dynamic incomingSDPOffer;
  final signallingServerAddress = TextEditingController(
    text: Consts.websocketUrl,
  );
  final remoteCallerIdTextEditingController = TextEditingController();
  final selfCallerIdTextEditingController = TextEditingController(
      text: Random().nextInt(999999).toString().padLeft(6, '0')
  );

  final socketStatusTextController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // listen for incoming video call
    SignallingService.instance.on(WebRtcConnectionManager.eventSdpOffer, (data) {
      printFromSocket(WebRtcConnectionManager.eventSdpOffer, data);
      if (mounted) {
        // set SDP Offer of incoming call
        setState(() => incomingSDPOffer = data);
      }
    });
  }

  // join Call
  _joinCall({
    required String localId,
    required String peerId,
    dynamic offer,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen2(
          localId: localId,
          peerId: peerId,
          offer: offer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        centerTitle: true,
        title: const Text("P2P Call App"),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextField(
                      controller: signallingServerAddress,
                      //readOnly: true,
                      textAlign: TextAlign.center,
                      enableInteractiveSelection: true,
                      decoration: InputDecoration(
                        labelText: "Signalling Server Address",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    TextField(
                      controller: selfCallerIdTextEditingController,
                      //readOnly: true,
                      textAlign: TextAlign.center,
                      enableInteractiveSelection: true,
                      decoration: InputDecoration(
                        labelText: "Your Caller ID",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: remoteCallerIdTextEditingController,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: "Remote Caller ID",
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        side: const BorderSide(color: Colors.white30),
                      ),
                      child: const Text(
                        "Init Socket",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () {
                        SignallingService.instance.init(
                          websocketUrl: signallingServerAddress.text,
                          selfCallerID: selfCallerIdTextEditingController.text,
                          onConnect: (data) => socketStatusTextController.text = "socket connected!",
                          onConnectError: (data) => socketStatusTextController.text = "socket connection error!",
                          onDisConnect: (data) => socketStatusTextController.text = "socket disconnected!",
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        side: const BorderSide(color: Colors.white30),
                      ),
                      child: const Text(
                        "Invite",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () {
                        _joinCall(
                          localId: selfCallerIdTextEditingController.text,
                          peerId: remoteCallerIdTextEditingController.text,
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: socketStatusTextController,
                      readOnly: true,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            if (incomingSDPOffer != null)
              Positioned(
                child: ListTile(
                  title: Text(
                    "Incoming Call from ${incomingSDPOffer[WebRtcConnectionManager.keySenderId]}",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.call_end),
                        color: Colors.redAccent,
                        onPressed: () {
                          SignallingService.instance.emit(
                              WebRtcConnectionManager.eventSdpAnswer,
                              {
                                WebRtcConnectionManager.keySenderId : selfCallerIdTextEditingController.text,
                                WebRtcConnectionManager.keyReceiverId : incomingSDPOffer[WebRtcConnectionManager.keySenderId]!,
                                WebRtcConnectionManager.keyAcceptCall : false,
                              }
                          );
                          setState(() => incomingSDPOffer = null);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.call),
                        color: Colors.greenAccent,
                        onPressed: () {
                          _joinCall(
                            localId: selfCallerIdTextEditingController.text,
                            peerId: incomingSDPOffer[WebRtcConnectionManager.keySenderId]!,
                            offer: incomingSDPOffer["sdpOffer"],
                          );
                        },
                      )
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}