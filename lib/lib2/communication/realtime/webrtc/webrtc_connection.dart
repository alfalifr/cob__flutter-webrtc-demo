import 'dart:developer';

import 'package:cob_duplication_flutter_webrtc/lib2/communication/channel/channels.dart';
import 'package:cob_duplication_flutter_webrtc/lib2/communication/const.dart';
import 'package:cob_duplication_flutter_webrtc/src/utils/collections.dart';
import 'package:cob_duplication_flutter_webrtc/src/utils/maps.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRtcConnection {
  //TODO [2024-05-23]: CONTINUE LAST HERE!!! Add stop calling signal.
  static const String socketEventOfferingOut = "connection_offering_out";
  static const String socketEventOfferingIn = "connection_offering_in";
  static const String socketEventOfferingAnswerOut = "connection_offering_answer_out";
  static const String socketEventOfferingAnswerIn = "connection_offering_answer_in";
  static const String socketEventIceCandidateOut = "ice_candidate_out";
  static const String socketEventIceCandidateIn = "ice_candidate_in";

  static const String keyCallerId = "callerId";
  static const String keyCalleeId = "calleeId";
  static const String keySdpOffer = "sdpOffer";
  static const String keySdpAnswer = "sdpAnswer";
  static const String keyAcceptCall = "acceptCall";
  static const String keyIceCandidate = "iceCandidate";
  static const String keySenderId = "senderId";
  static const String keyReceiverId = "receiverId";

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
  final String roomId;

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

  void Function(RTCTrackEvent)? _onMediaTrack;
  set onMediaTrack(void Function(RTCTrackEvent)? l) {
    _onMediaTrack = l;
    _rtcConnection?.onTrack = l;
  }


  WebRtcConnection({
    required InOutChannel commChannel,
    required this.roomId,
  }) : _commChannel = commChannel;


  /*
   * Offering data format:
   * {
   *   "callerId" : "...",
   *   "calleeId" : "...",
   *   "sdpOffer" : {
   *     "sdp" : "...",
   *     "type" : "..."
   *   }
   * }
   */
  /*
   * Offering answer data format:
   * {
   *   "calleeId" : "...",
   *   "callerId" : "...",
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
    ;

    if(_remoteSdp != null) {
      _rtcConnection?.setRemoteDescription(_remoteSdp!);
    }

    for (final stream in _mediaStreamList) {
      stream.getTracks().forEach((track) {
        _rtcConnection?.addTrack(track, stream);
      });
    }
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
  void doOfferingProcedure(
      String calleeId, {
        Map<String, String>? offeringData,
        void Function(bool callAccepted)? onAnswer,
  }) async {
    _listenForSdpAnswer(onAnswer: (callAccepted) {
      log("=== WebRtcConnection.doOfferingProcedure._listenForSdpAnswer() callAccepted=$callAccepted");
      if(callAccepted) {
        _sendIceCandidate(calleeId);
      }
    });
    _setOnIceCandidateListener();
    await _sdpOffer(calleeId, offeringData: offeringData);
  }

  void prepareAsCallee({void Function(Map<String, dynamic> data)? onOffered}) {
    _listenForSdpOffer(onOffered: onOffered);
    _receiveIceCandidate();
  }

  void stopBeingCallee() {
    _listenForSdpOffer(onOffered: null);
    _stopReceivingIceCandidate();
  }

  Future<void> _sdpOffer(
      String calleeId,
      {Map<String, String>? offeringData}
  ) async {
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
        socketEventOfferingOut,
        _dataForCallee(
            calleeId: calleeId,
            data: {
              keyCallerId : roomId,
              "sdpOffer" : offering.toMap(),
            },
        ),
      );
  }

  _listenForSdpAnswer({void Function(bool callAccepted)? onAnswer}) {
    _commChannel
      .listen(socketEventOfferingAnswerIn, (data) async {
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

  _listenForSdpOffer({void Function(Map<String, dynamic> data)? onOffered}) {
    _commChannel
      .listen(socketEventOfferingIn, (data) async {
        onOffered?.call(data);
      });
  }



  Future<void> answerCall(
      String callerId, {
        bool acceptCall = true,
        Map<String, String>? offeringAnswerData,
  }) => _sdpAnswer(
      callerId,
      acceptCall: acceptCall,
      offeringAnswerData: offeringAnswerData,
  );

  Future<void> _sdpAnswer(
      String callerId, {
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
            socketEventOfferingAnswerOut,
            _dataForCaller(
                callerId: callerId,
                data: {
                  keyCalleeId : roomId,
                  keyAcceptCall : acceptCall,
                  "sdpAnswer" : answer.toMap(),
                },
            ),
        );
    log("=== WebRtcConnection._sdpAnswer() - 4 ===");
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

  _sendIceCandidate(String roomId, {List<RTCIceCandidate>? iceCandidateList}) {
    log("=== WebRtcConnection._sendIceCandidate() - 1 ===");
    final usedIceCandidateList = iceCandidateList ?? _iceCandidateList;
    for (var iceCandidate in usedIceCandidateList) {
      _commChannel.emit(
        socketEventIceCandidateOut,
        {
          keyReceiverId : roomId,
          keySenderId : this.roomId,
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
    _commChannel.listen(socketEventIceCandidateIn, (data) {
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
    _commChannel.listen(socketEventIceCandidateIn, null);
  }

  void dispose() {
    _rtcConnection?.dispose();
    _commChannel
      ..listen(socketEventOfferingAnswerIn, null)
      ..listen(socketEventOfferingIn, null)
      ..listen(socketEventIceCandidateIn, null)
    ;
  }
}