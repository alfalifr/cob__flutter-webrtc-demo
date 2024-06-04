import '../../../../src/utils/prints.dart';

import 'package:cob_duplication_flutter_webrtc/lib2/communication/realtime/webrtc/webrtc_connection_utils.dart';
import 'package:cob_duplication_flutter_webrtc/lib2/model/item_with_id.dart';
import 'package:cob_duplication_flutter_webrtc/src/utils/collections.dart';
import 'package:cob_duplication_flutter_webrtc/src/utils/maps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../lib2/communication/realtime/webrtc/webrtc_connection.dart';
import '../../lib2/communication/realtime/webrtc/webrtc_connection_multi.dart';
import '../services/signalling_service.dart';
import '../utils/prints.dart';

class CallScreen3 extends StatefulWidget {
  final String localId, peerId, localDeviceId;
  final dynamic offer;

  const CallScreen3({
    super.key,
    this.offer,
    required this.localId,
    required this.peerId,
    required this.localDeviceId,
  });

  @override
  State<CallScreen3> createState() => _CallScreenState2();
}

class _CallScreenState2 extends State<CallScreen3> {
  // channel instance
  //final socket = SignallingService.instance.socket;

  // videoRenderer for localPeer
  final _localRTCVideoRenderer = RTCVideoRenderer();

  // videoRenderer for remotePeer
  //final _remoteRTCVideoRenderer = RTCVideoRenderer();

  late WebRtcConnectionManagerMulti _rtcConnectionManager;

  // mediaStream for localPeer
  MediaStream? _localStream;

  final _remoteVideoRenderer = <String /*peerId*/, List<RTCVideoRenderer>>{};

  // RTC peer connection
  //RTCPeerConnection? _rtcPeerConnection;

  // list of rtcCandidates to be sent over signalling
  //List<RTCIceCandidate> rtcIceCadidates = [];

  // media status
  bool isAudioOn = false, isVideoOn = true, isFrontCameraSelected = true;

  bool isLeaving = false;

  @override
  void initState() {
    // initializing renderers
    _localRTCVideoRenderer.initialize();

    // setup Peer Connection
    _setupPeerConnection();
    super.initState();
  }

  @override
  void setState(fn) async {
    log("=== CallScreen3.setState() - 1 === _remoteVideoRenderer.length=${_remoteVideoRenderer.length}");;
    log("=== CallScreen3.setState() - 2 === _remoteVideoRenderer=$_remoteVideoRenderer");
    if (mounted) {
      //await _loadLocalStream();
      super.setState(fn);
      log("=== CallScreen3.setState() - 3 - MOUNTED === _remoteVideoRenderer.length=${_remoteVideoRenderer.length}");;
      log("=== CallScreen3.setState() - 4 - MOUNTED === _remoteVideoRenderer=$_remoteVideoRenderer");
    }
  }

  Future<void> _loadLocalStream() async {
    log("=== CallScreen3._loadLocalStream() - 1 - === _localStream == null=${_localStream == null}");;
    log("=== CallScreen3._loadLocalStream() - 2 - === _remoteVideoRenderer.length=${_remoteVideoRenderer.length}");;

    // get localStream
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': isAudioOn,
      'video': isVideoOn
          ? {'facingMode': isFrontCameraSelected ? 'user' : 'environment'}
          : false,
    });

    // set source for local video renderer
    _localRTCVideoRenderer.srcObject = _localStream;

    // add mediaTrack to peerConnection
    _rtcConnectionManager.localMediaStream = _localStream;
  }

  _setupPeerConnection() async {
    log("=== CallScreen3._setupPeerConnection() - 1 === widget.offer == null => ${widget.offer == null}");
    //*
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
    // */


    _rtcConnectionManager = WebRtcConnectionUtils.getConnectionFromSocketIo_multi(
      socket: SignallingService.instance.socket!,
      localId: widget.localId,
      localDeviceId: widget.localDeviceId,
    )
      // add mediaTrack to peerConnection
      ..localMediaStream = _localStream

      // listen for remotePeer mediaTrack event
      ..onMediaTrack = (peerId, event) async {
        log("=== CallScreen3._setupPeerConnection.onMediaTrack() - 1 === peerId=$peerId");
        printFromPeerConnection("onTrack", event);
        printFromPeerConnection("onTrack event.streams", event.streams);
        printFromPeerConnection("onTrack event.streams.length", event.streams.length);
        log("=== CallScreen3._setupPeerConnection.onMediaTrack() - 2 === peerId=$peerId event.streams.length=${event.streams.length}");
        final streamList = event.streams;
        await _setupRendererStream(peerId: peerId, streamList: streamList);
        setState(() {});
      }
      ..onStopCall = (peerId) {
        log("=== CallScreen3._setupPeerConnection.onStopCall() - 1 === peerId=$peerId");
        _stopCall(peerId);
        //Navigator.pop(context)
      }
    ;
    _rtcConnectionManager.init();

    //setState((){}); //_loadLocalStream();

    log("=== CallScreen3._setupPeerConnection() - 2 === widget.offer == null => ${widget.offer == null}");

    // Outgoing call
    if(widget.offer == null) {
      final peerIdList = widget.peerId.split(",").map((it) => it.trim()).toList();
      _rtcConnectionManager.doOfferingProcedure(
        peerIdList: peerIdList,
        onAnswer: (peerId, callAccepted) {
          if(!callAccepted) {
            //_leaveCall();
          }
        }
      );
    }
    // Incoming call
    else {
      // _rtcConnectionManager.prepareAsCallee();
      await _rtcConnectionManager.setRemoteSdpFromMap(
        peerId: widget.peerId,
        sdpData: widget.offer,
      );
      await _rtcConnectionManager.answerCall(
        peerId: widget.peerId,
        acceptCall: true,
      );
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

  Future<void> _setupRendererStream({
    required String peerId,
    required List<MediaStream> streamList,
  }) async {
    log("=== CallScreen3._setupRendererStream() - 1 === peerId=$peerId streamList.length=${streamList.length}");

    _remoteVideoRenderer.remove(peerId)?.forEach((it) => it.dispose());

    final newRendererList = <RTCVideoRenderer>[];
    for(final stream in streamList) {
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      renderer.srcObject = stream;
      newRendererList.add(renderer);
    }
    _remoteVideoRenderer[peerId] = newRendererList;

    log("=== CallScreen3._setupRendererStream() - 2 === peerId=$peerId newRendererList.length=${newRendererList.length}");
  }

  _stopCall(String peerId) {
    log("=== CallScreen3._stopCall() - 1 === peerId=$peerId _remoteVideoRenderer.length=${_remoteVideoRenderer.length}");
    _remoteVideoRenderer.remove(peerId)?.forEach((list) => list.dispose());
    log("=== CallScreen3._stopCall() - 2 === peerId=$peerId _remoteVideoRenderer.length=${_remoteVideoRenderer.length}");
    if(_remoteVideoRenderer.isEmpty) {
      if(mounted && !isLeaving) {
        Navigator.pop(context);
      }
    } else {
      setState(() {});
    }
  }

  _leaveCall() {
    isLeaving = true;
    _rtcConnectionManager.leaveCall();
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
                GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2
                    ),
                    itemCount: _remoteVideoRenderer.flattenedValueLength,
                    itemBuilder: (context, position) {
                      final remoteVideoRenderer = _remoteVideoRenderer.flattenedValues.toList()[position];
                      return RTCVideoView(
                        remoteVideoRenderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      );
                    },
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
    if(!isLeaving) {
      _rtcConnectionManager.leaveCall();
    }
    _rtcConnectionManager.dispose();
    _localRTCVideoRenderer.dispose();
    _localStream?.dispose();
    for(final renderer in _remoteVideoRenderer.flattenedValues) {
      renderer.dispose();
    }
    //_rtcPeerConnection?.dispose();
    super.dispose();
  }
}