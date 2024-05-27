import 'dart:developer';

import 'package:cob_duplication_flutter_webrtc/lib2/communication/channel/channels.dart';
import 'package:cob_duplication_flutter_webrtc/lib2/communication/const.dart';
import 'package:cob_duplication_flutter_webrtc/src/utils/maps.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

///
/// This class represents a peer connection 2 devices, local and remote device.
///
class WebRtcConnectionManager {
  static const String eventSdpOffer = "sdp_offer";
  static const String eventSdpAnswer = "sdp_answer";
  static const String eventIceCandidate = "ice_candidate";
  static const String eventStopCall = "stop_call";

  static const String keySenderId = "senderId";
  static const String keyReceiverId = "receiverId";
  static const String keySdpOffer = "sdpOffer";
  static const String keySdpAnswer = "sdpAnswer";
  static const String keyAcceptCall = "acceptCall";
  static const String keyIceCandidate = "iceCandidate";

  static Map<String, dynamic> _dataForCaller({
    required String callerId,
    required Map<String, dynamic> data,
  }) => mergeMaps([
    { "callerId" : callerId },
    data,
  ]);

  static Map<String, dynamic> _dataForCallee({
    required String calleeId,
    required Map<String, dynamic> data,
  }) => mergeMaps([
    { "calleeId" : calleeId },
    data,
  ]);


  final InOutChannel _commChannel;
  final String localId;
  final String peerId;

  RTCPeerConnection? _rtcConnection;

  final _iceCandidateList = <RTCIceCandidate>[];
  final _mediaStreamList = <MediaStream>[];

  RTCSessionDescription? _remoteSdp;
  Future<void> setRemoteSdpFromMap(Map<String, dynamic>? sdp) async {
    _remoteSdp = sdp != null
      ? RTCSessionDescription(
        sdp["sdp"],
        sdp["type"],
      ) : null
    ;
    if(_remoteSdp != null) {
      await _rtcConnection?.setRemoteDescription(_remoteSdp!);
    }
  }

  void Function()? _onStopCall;
  set onStopCall(void Function()? l) {
    _onStopCall = l;
    _attachOnStopCallListener();
  }
  void _attachOnStopCallListener() {
    _rtcConnection?.onConnectionState = (state) {
      if(state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _onStopCall?.call();
      }
    };
  }


  void Function(RTCTrackEvent)? _onMediaTrack;
  set onMediaTrack(void Function(RTCTrackEvent)? l) {
    _onMediaTrack = l;
    _rtcConnection?.onTrack = l;
  }


  WebRtcConnectionManager({
    required InOutChannel commChannel,
    required this.localId,
    required this.peerId,
  }) : _commChannel = commChannel;


  /*
   * Offering data format:
   * {
   *   "senderId" : "...",
   *   "receiverId" : "...",
   *   "sdpOffer" : {
   *     "sdp" : "...",
   *     "type" : "..."
   *   }
   * }
   */
  /*
   * Offering answer data format:
   * {
   *   "senderId" : "...",
   *   "receiverId" : "...",
   *   "acceptCall" : true,
   *   "sdpAnswer" : {
   *     "sdp" : "...",
   *     "type" : "..."
   *   }
   * }
   */
  /*
   * ICE candidate data format:
   * {
   *   "senderId" : "...",
   *   "receiverId" : "...",
   *   "iceCandidate" : {
   *      ...
   *   }
   * }
   */
  /*
   * Stop calling data format:
   * {
   *   "senderId" : "...",
   *   "receiverId" : "...",
   * }
   */

  Future<void> init() async {
    _rtcConnection = await createPeerConnection(
        {
          "iceServers": [
            {
              "urls": [
                Consts.stunServerAddress1,
                Consts.stunServerAddress2,
              ]
            }
          ]
        }
    )
      ..onTrack = _onMediaTrack
      ..onAddTrack = (stream, track) {
        log("=== WebRtcConnection._rtcConnection.onAddTrack() streamId=${stream.id} trackId=${track.id}");
      }
      ..onRemoveTrack = (stream, track) {
        log("=== WebRtcConnection._rtcConnection.onRemoveTrack() streamId=${stream.id} trackId=${track.id}");
      }
      ..onAddStream = (stream) {
        log("=== WebRtcConnection._rtcConnection.onAddStream() streamId=${stream.id}");
      }
      ..onRemoveStream = (stream) {
        log("=== WebRtcConnection._rtcConnection.onRemoveStream() streamId=${stream.id}");
      }
    ;

    if(_remoteSdp != null) {
      _rtcConnection?.setRemoteDescription(_remoteSdp!);
    }

    for (final stream in _mediaStreamList) {
      stream.getTracks().forEach((track) {
        _rtcConnection?.addTrack(track, stream);
      });
    }

    _attachOnStopCallListener();
    _listenToStopCallEvent();
  }

  void addMediaTrackFromMediaStream(MediaStream stream) {
    _mediaStreamList.add(stream);
    if(_rtcConnection != null) {
      stream.getTracks().forEach((track) {
        _rtcConnection?.addTrack(track, stream);
      });
    }
  }

  /*
   * Offering mechanism:
   * 1. Setup SDP answer listener.
   * 2. Setup ICE candidate listener so the newly created local ICE candidate can be caught.
   * 3. Offer the SDP.
   */
  void doOfferingProcedure({
        Map<String, String>? offeringData,
        void Function(bool callAccepted)? onAnswer,
  }) async {
    _listenForSdpAnswer(onAnswer: (callAccepted) {
      log("=== WebRtcConnection.doOfferingProcedure._listenForSdpAnswer() callAccepted=$callAccepted");
      if(callAccepted) {
        _sendIceCandidate();
      }
      onAnswer?.call(callAccepted);
    });
    _setOnIceCandidateListener();
    await _sdpOffer(offeringData: offeringData);
  }

  void prepareAsCallee({void Function(Map<String, dynamic> data)? onOffered}) {
    _listenForSdpOffer(onOffered: onOffered);
    _receiveIceCandidate();
  }

  void stopBeingCallee() {
    _listenForSdpOffer(onOffered: null);
    _stopReceivingIceCandidate();
  }

  Future<void> _sdpOffer({Map<String, String>? offeringData}) async {
    final offering =
        offeringData != null
            ? RTCSessionDescription(
              offeringData["sdp"],
              offeringData["type"],
            )
            : await _rtcConnection!.createOffer()
    ;

    // set SDP offer as localDescription for peerConnection
    await _rtcConnection!.setLocalDescription(offering);

    _commChannel
      .emit(
        eventSdpOffer,
        {
          keySenderId : localId,
          keyReceiverId : peerId,
          "sdpOffer" : offering.toMap(),
        }
      );
  }

  _listenForSdpOffer({void Function(Map<String, dynamic> data)? onOffered}) {
    _commChannel
        .listen(eventSdpOffer, (data) async {
      onOffered?.call(data);
    });
  }

  Future<void> answerCall({
    bool acceptCall = true,
    Map<String, String>? offeringAnswerData,
  }) => _sdpAnswer(
    acceptCall: acceptCall,
    offeringAnswerData: offeringAnswerData,
  );

  Future<void> _sdpAnswer({
    bool acceptCall = true,
    Map<String, String>? offeringAnswerData,
  }) async {
    log("=== WebRtcConnection._sdpAnswer() - 1 ===");

    final answer =
      offeringAnswerData != null
        ? RTCSessionDescription(
          offeringAnswerData["sdp"],
          offeringAnswerData["type"],
        )
        : await _rtcConnection!.createAnswer()
    ;

    log("=== WebRtcConnection._sdpAnswer() - 2 ===");

    // set SDP answer as localDescription for peerConnection
    await _rtcConnection!.setLocalDescription(answer);

    log("=== WebRtcConnection._sdpAnswer() - 3 ===");

    _commChannel
        .emit(
            eventSdpAnswer,
            {
              keySenderId : localId,
              keyReceiverId : peerId,
              keyAcceptCall : acceptCall,
              "sdpAnswer" : answer.toMap(),
            },
        );
    log("=== WebRtcConnection._sdpAnswer() - 4 ===");
  }

  _listenForSdpAnswer({void Function(bool callAccepted)? onAnswer}) {
    _commChannel
        .listen(eventSdpAnswer, (data) async {
      bool callAccepted = data[keyAcceptCall];
      if(!callAccepted) {
        onAnswer?.call(callAccepted);
        return;
      }
      final sdpAnswer = data[keySdpAnswer];
      await _rtcConnection!.setRemoteDescription(
        RTCSessionDescription(
          sdpAnswer["sdp"],
          sdpAnswer["type"],
        ),
      );
      onAnswer?.call(callAccepted);
    });
  }

  _setOnIceCandidateListener({
    void Function(RTCIceCandidate)? listener
  }) {
    _rtcConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      log("=== WebRtcConnection._sendIceCandidate.onIceCandidate() - 1 ===");
      if(_iceCandidateList.any((it) => it.sdpMid == candidate.sdpMid)) {
        log("=== WebRtcConnection._sendIceCandidate.onIceCandidate() - 2 - RETURN!!! ===");
        return;
      }
      log("=== WebRtcConnection._sendIceCandidate.onIceCandidate() - 3 ===");
      _iceCandidateList.add(candidate);
      listener?.call(candidate);
      log("=== WebRtcConnection._sendIceCandidate.onIceCandidate() - 4 ===");
    };
  }

  _sendIceCandidate({List<RTCIceCandidate>? iceCandidateList}) {
    log("=== WebRtcConnection._sendIceCandidate() - 1 ===");
    final usedIceCandidateList = iceCandidateList ?? _iceCandidateList;
    for (var iceCandidate in usedIceCandidateList) {
      _commChannel.emit(
        eventIceCandidate,
        {
          keySenderId : localId,
          keyReceiverId : peerId,
          keyIceCandidate : {
            "id": iceCandidate.sdpMid,
            "label": iceCandidate.sdpMLineIndex,
            "candidate": iceCandidate.candidate,
          },
        },
      );
    }
  }

  _receiveIceCandidate() {
    _commChannel.listen(eventIceCandidate, (data) {
      final candidate = data[keyIceCandidate];
      String candidateStr = candidate["candidate"];
      String sdpMid = candidate["id"];
      int sdpMLineIndex = candidate["label"];

      final newCandidate = RTCIceCandidate(
        candidateStr,
        sdpMid,
        sdpMLineIndex,
      );

      _iceCandidateList.add(newCandidate);
      _rtcConnection!.addCandidate(newCandidate);
    });
  }

  _stopReceivingIceCandidate() {
    _commChannel.listen(eventIceCandidate, null);
  }

  stopCall() {
    _commChannel.emit(
        eventStopCall,
        {
          keySenderId : localId,
          keyReceiverId : peerId,
        },
    );
  }

  _listenToStopCallEvent() {
    _commChannel.listen(
      eventStopCall,
      (data) {
        _rtcConnection?.close();
        //_onStopCall?.call();
      }
    );
  }

  void dispose() {
    _rtcConnection?.dispose();
    _commChannel
      ..listen(eventSdpOffer, null)
      ..listen(eventSdpAnswer, null)
      ..listen(eventIceCandidate, null)
    ;
  }
}