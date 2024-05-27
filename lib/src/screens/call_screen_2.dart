import 'dart:developer';

import 'package:cob_duplication_flutter_webrtc/lib2/communication/realtime/webrtc/webrtc_connection_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../lib2/communication/realtime/webrtc/webrtc_connection.dart';
import '../services/signalling_service.dart';
import '../utils/prints.dart';

class CallScreen2 extends StatefulWidget {
  final String localId, peerId, localDeviceId;
  final dynamic offer;

  const CallScreen2({
    super.key,
    this.offer,
    required this.localId,
    required this.peerId,
    required this.localDeviceId,
  });

  @override
  State<CallScreen2> createState() => _CallScreenState2();
}

class _CallScreenState2 extends State<CallScreen2> {
  // channel instance
  //final socket = SignallingService.instance.socket;

  // videoRenderer for localPeer
  final _localRTCVideoRenderer = RTCVideoRenderer();

  // videoRenderer for remotePeer
  final _remoteRTCVideoRenderer = RTCVideoRenderer();

  late WebRtcConnectionManager _rtcConnectionManager;

  // mediaStream for localPeer
  MediaStream? _localStream;

  // RTC peer connection
  //RTCPeerConnection? _rtcPeerConnection;

  // list of rtcCandidates to be sent over signalling
  //List<RTCIceCandidate> rtcIceCadidates = [];

  // media status
  bool isAudioOn = false, isVideoOn = true, isFrontCameraSelected = true;

  @override
  void initState() {
    // initializing renderers
    _localRTCVideoRenderer.initialize();
    _remoteRTCVideoRenderer.initialize();

    // setup Peer Connection
    _setupPeerConnection();
    super.initState();
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  _setupPeerConnection() async {
    log("=== CallScreen2._setupPeerConnection() - 1 === widget.offer == null => ${widget.offer == null}");
    // get localStream
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': isAudioOn,
      'video': isVideoOn
          ? {'facingMode': isFrontCameraSelected ? 'user' : 'environment'}
          : false,
    });

    // set source for local video renderer
    _localRTCVideoRenderer.srcObject = _localStream;
    setState(() {});

    _rtcConnectionManager = WebRtcConnectionUtils.getConnectionFromSocketIo(
      socket: SignallingService.instance.socket!,
      localId: widget.localId,
      peerId: widget.peerId,
      localDeviceId: widget.localDeviceId,
    )
      // add mediaTrack to peerConnection
      ..addMediaTrackFromMediaStream(_localStream!)

      // listen for remotePeer mediaTrack event
      ..onMediaTrack = (event) {
        printFromPeerConnection("onTrack", event);
        printFromPeerConnection("onTrack event.streams", event.streams);
        printFromPeerConnection("onTrack event.streams.length", event.streams.length);
        _remoteRTCVideoRenderer.srcObject = event.streams[0];
        setState(() {});
      }
      ..onStopCall = () => Navigator.pop(context)
    ;
    await _rtcConnectionManager.init();

    log("=== CallScreen2._setupPeerConnection() - 2 === widget.offer == null => ${widget.offer == null}");

    // Outgoing call
    if(widget.offer == null) {
      _rtcConnectionManager.doOfferingProcedure(
        onAnswer: (callAccepted) {
          if(!callAccepted) {
            _leaveCall();
          }
        }
      );
    }
    // Incoming call
    else {
      _rtcConnectionManager.prepareAsCallee();
      await _rtcConnectionManager.setRemoteSdpFromMap(widget.offer);
      await _rtcConnectionManager.answerCall(acceptCall: true);
    }

    /*
    // create peer connection
    _rtcPeerConnection = await createPeerConnection({
      'iceServers': [
        {
          'urls': [
            'stun:stun1.l.google.com:19302',
            'stun:stun2.l.google.com:19302'
          ]
        }
      ]
    });
     */
  }

  _leaveCall() {
    _rtcConnectionManager.stopCall();
    Navigator.pop(context);
  }

  _toggleMic([bool? enabled]) {
    // change status
    isAudioOn = enabled ?? !isAudioOn;
    // enable or disable audio track
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = isAudioOn;
    });
    setState(() {});
  }

  _toggleCamera() {
    // change status
    isVideoOn = !isVideoOn;

    // enable or disable video track
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = isVideoOn;
    });
    setState(() {});
  }

  _switchCamera() {
    // change status
    isFrontCameraSelected = !isFrontCameraSelected;

    // switch camera
    _localStream?.getVideoTracks().forEach((track) {
      // ignore: deprecated_member_use
      track.switchCamera();
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text("P2P Call App"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(children: [
                RTCVideoView(
                  _remoteRTCVideoRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: SizedBox(
                    height: 150,
                    width: 120,
                    child: RTCVideoView(
                      _localRTCVideoRenderer,
                      mirror: isFrontCameraSelected,
                      objectFit:
                      RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                )
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: Icon(isAudioOn ? Icons.mic : Icons.mic_off),
                    onPressed: _toggleMic,
                  ),
                  IconButton(
                    icon: const Icon(Icons.call_end),
                    iconSize: 30,
                    onPressed: _leaveCall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.cameraswitch),
                    onPressed: _switchCamera,
                  ),
                  IconButton(
                    icon: Icon(isVideoOn ? Icons.videocam : Icons.videocam_off),
                    onPressed: _toggleCamera,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _rtcConnectionManager.dispose();
    _localRTCVideoRenderer.dispose();
    _remoteRTCVideoRenderer.dispose();
    _localStream?.dispose();
    //_rtcPeerConnection?.dispose();
    super.dispose();
  }
}