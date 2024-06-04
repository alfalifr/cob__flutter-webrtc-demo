

import 'package:cob_duplication_flutter_webrtc/lib2/communication/channel/channels.dart';
import 'package:cob_duplication_flutter_webrtc/lib2/communication/channel/webrtc_channel.dart';
import 'package:cob_duplication_flutter_webrtc/lib2/communication/const.dart';
import 'package:cob_duplication_flutter_webrtc/src/utils/collections.dart';
import 'package:cob_duplication_flutter_webrtc/src/utils/maps.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../src/utils/prints.dart';

///
/// This class represents a peer connection 2 devices, local and remote device.
///
class WebRtcConnectionManagerMulti {

  WebRtcConnectionManagerMulti({
    required WebRtcChannel commChannel,
    required this.localId,
    required this.localDeviceId,
  }) : _commChannel = commChannel;

  final WebRtcChannel _commChannel;
  final String localId;
  final String localDeviceId;

  /*
  // TODO [HIGH]: DELETE THESE VARS!!!
  RTCPeerConnection? _initialConnection;
  RTCSessionDescription? __initialSdpOffer;
  RTCSessionDescription? get _initialSdpOffer => __initialSdpOffer;
  set _initialSdpOffer(v) {
    log("=== WebRtcConnectionManagerMulti.set _initialSdpOffer -  === _initialSdpOffer?.toMap()=${_initialSdpOffer?.toMap()}");
    __initialSdpOffer = v;
  }
   */

  final _registeredPeerIdList = <String>{};

  final _rtcConnections = <String /*peerId*/, RTCPeerConnection>{};

  final _localIceCandidateMap = <String /*peerId*/, List<RTCIceCandidate>>{};
  final _mediaStreamMap = <String /*peerId*/, List<MediaStream>>{};
  MediaStream? _localMediaStream;
  set localMediaStream(MediaStream? stream) {
    _localMediaStream = stream;
    _attachLocalMediaStream();
  }
  final _localMediaTrackSenders = <String, List<RTCRtpSender>>{};

  final _remoteSdps = <String /*peerId*/, RTCSessionDescription>{};
  Future<void> setRemoteSdpFromMap({
    required String peerId,
    required Map<String, dynamic>? sdpData,
  }) async {
    log("=== WebRtcConnection.setRemoteSdpFromMap() - 1 === sdpData != null => ${sdpData != null}");

    if(sdpData != null) {
      final sdp = _remoteSdps[peerId] = RTCSessionDescription(
        sdpData["sdp"],
        sdpData["type"],
      );
      final connection = _rtcConnections[peerId];
      log("=== WebRtcConnection.setRemoteSdpFromMap() - 2 === connection != null => ${connection != null}");
      if(connection != null) {
        if((connection.connectionState?.index ?? 0) <
            RTCPeerConnectionState.RTCPeerConnectionStateConnecting.index
        ) {
          await connection.setRemoteDescription(sdp);
        }
      }
    } else {
      _remoteSdps.remove(peerId);
    }
  }

  void Function(String peerId)? _onStopCall;
  set onStopCall(void Function(String peerId)? l) {
    _onStopCall = l;
    _attachOnStopCallListener();
  }
  void _attachOnStopCallListener() {
    for(final rtcConnectionPair in _rtcConnections.entries) {
      final connectionId = rtcConnectionPair.key;
      _setOnConnectionStateListener(peerId: connectionId);
    }
  }
  void _setOnConnectionStateListener({required String peerId}) {
    _rtcConnections[peerId]?.onConnectionState = (state) {
      if(state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        if(_rtcConnections[peerId] != null) {
          _onStopCall?.call(peerId);
        }
      }
    };
  }

  void Function()? _onEndCall;
  set onEndCall(void Function()? l) {
    _onEndCall = l;
  }



  Future<void> _attachLocalMediaStreamToConnection({
    required String peerId,
  }) async {
    final stream = _localMediaStream;
    if(stream == null) {
      return;
    }
    final connection = _rtcConnections[peerId];
    if(connection == null) {
      return;
    }
    final senderList = _localMediaTrackSenders[peerId] ??= [];
    for(final currentSender in senderList) {
      connection.removeTrack(currentSender);
    }
    for(final track in stream.getTracks()) {
      senderList.add(
          await connection.addTrack(track, stream)
      );
    }
  }

  Future<void> _attachLocalMediaStream() async {
    for(final peerId in _rtcConnections.keys) {
      await _attachLocalMediaStreamToConnection(peerId: peerId);
    }
  }

  void _attachMediaStreamToConnection({
    required String peerId,
  }) async {
    final stream = _localMediaStream;
    final connection = await _requireConnection(peerId);
    for(final stream in _mediaStreamMap[peerId] ?? []) {
      stream.getTracks().forEach((track) {
        connection.addTrack(track, stream);
      });
    }
  }


  void Function(String peerId, RTCTrackEvent)? _onMediaTrack;
  set onMediaTrack(void Function(String peerId, RTCTrackEvent)? l) {
    _onMediaTrack = l;
  }

  void Function(String peerId, Map<String, dynamic> data)? _onOffered;
  set onOffered(void Function(String peerId, Map<String, dynamic> data)? l) {
    _onOffered = l;
  }



  /*
   * Offering data format:
   * {
   *   "senderDeviceId" : "...",
   *   "senderId" : "...",
   *   "receiverId" : "...",
   *   "sdpOffer" : {
   *     "sdp" : "...",
   *     "type" : "..."
   *   },
   *   "extraData" : {
   *     "forceAccept" : true,
   *     "forwardCallToOtherPeers" : false,
   *   },
   * }
   */
  /*
   * Offering answer data format:
   * {
   *   "senderDeviceId" : "...",
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
   *   "senderDeviceId" : "...",
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
   *   "senderDeviceId" : "...",
   *   "senderId" : "...",
   *   "receiverId" : "...",
   * }
   */
  /*
   * Peer ID list to connect to data format:
   *  {
   *    "senderDeviceId" : "...",
   *    "senderId" : "...",
   *    "receiverId" : "...",
   *    "peerIdList" : [
   *      ...
   *    ],
   *  }
   */

  void init() {
    _listenToStopCallEvent();
    _listenForPeerIdListToConnect();
    prepareAsCallee();
    _listenForSdpAnswer();
    _listenToEndCallEvent();
  }

  Future<RTCPeerConnection> _createInitialConnection() async {
    final rtcConnection = await createPeerConnection(
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
    );
    return rtcConnection;
  }

  Future<RTCPeerConnection> _initConnection({
    required final String peerId,
    bool recreate = true
  }) async {
    var rtcConnection = _rtcConnections[peerId];
    log("=== WebRtcConnection._initConnection() peerId=$peerId recreate=$recreate rtcConnection != null => ${rtcConnection != null}");
    if(rtcConnection == null || recreate) {
      log("=== WebRtcConnection._initConnection() peerId=$peerId IF rtcConnection=$rtcConnection");
      rtcConnection = _rtcConnections[peerId] = await _createInitialConnection();
      rtcConnection
        // In this case (2024-05-31), `onIceCandidate` only collects ICE candidate from local peer by a call to `setLocalDescription`
        ..onIceCandidate = (RTCIceCandidate candidate) {
          log("=== WebRtcConnection._attachOnIceCandidateListener.onIceCandidate() - 1 ===");
          final iceCandidateList = _localIceCandidateMap[peerId] ??= [];
          if(iceCandidateList.any((it) => it.sdpMid == candidate.sdpMid)) {
            log("=== WebRtcConnection._attachOnIceCandidateListener.onIceCandidate() - 2 - RETURN!!! ===");
            return;
          }
          log("=== WebRtcConnection._attachOnIceCandidateListener.onIceCandidate() - 3 ===");
          iceCandidateList.add(candidate);
          log("=== WebRtcConnection._attachOnIceCandidateListener.onIceCandidate() - 4 ===");
        }
        ..onTrack = (trackEvent) {
          log("=== WebRtcConnection._rtcConnection.onTrack() - 1 === peerId=$peerId");
          final stream = trackEvent.streams[0];
          log("=== WebRtcConnection._rtcConnection.onTrack() - 2 === peerId=$peerId streamId=${stream.id}");
          log("=== WebRtcConnection._rtcConnection.onTrack() - 3 === peerId=$peerId trackEvent.streams.length=${trackEvent.streams.length}");
          //_addMediaStreamToOtherConnection(srcPeerId: peerId, stream: stream);
          /*
          _addMediaStreamToOtherConnection(
              srcPeerId: peerId,
              stream: trackEvent.streams[0],
          );
         */
          _onMediaTrack?.call(peerId, trackEvent);
        }
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
    }

    /*
    log("=== WebRtcConnection._initConnection() peerId=$peerId _initialSdpOffer != null => ${_initialSdpOffer != null}");
    if(_initialSdpOffer != null) {
      await rtcConnection.setLocalDescription(_initialSdpOffer!);
    }
     */

    var usedRemoteSdp = _remoteSdps[peerId];
    log("=== WebRtcConnection._initConnection() peerId=$peerId usedRemoteSdp != null => ${usedRemoteSdp != null}");

    if(usedRemoteSdp != null) {
      if((rtcConnection.connectionState?.index ?? 0) <
          RTCPeerConnectionState.RTCPeerConnectionStateConnecting.index
      ) {
        await rtcConnection.setRemoteDescription(usedRemoteSdp);
      }
    }

    final mediaStreamList = _mediaStreamMap[peerId] ??= [];
    /*
    final localMediaStream = _localMediaStream;
    if(localMediaStream != null) {
      mediaStreamList.add(localMediaStream);
    }
     */
    await _attachLocalMediaStreamToConnection(peerId: peerId);

    log("=== WebRtcConnection._initConnection() peerId=$peerId mediaStreamList.size=${mediaStreamList.length}");
    //log("=== WebRtcConnection._initConnection() peerId=$peerId localMediaStream != null=> ${localMediaStream != null}");

    for (final stream in mediaStreamList) {
      log("=== WebRtcConnection._initConnection() for (final stream in mediaStreamList) peerId=$peerId stream.getTracks().length=${stream.getTracks().length}");
      log("=== WebRtcConnection._initConnection() for (final stream in mediaStreamList) peerId=$peerId");
      _addMediaStreamToConnection(
        peerId: peerId,
        connection: rtcConnection,
        stream: stream,
      );
    }

    _setOnConnectionStateListener(peerId: peerId);

    return rtcConnection;
  }

  Future<RTCPeerConnection> _requireConnection(
    String peerId, {
    bool createNewIfAbsent = false,
  }) async {
    log("=== WebRtcConnection._requireConnection() - 1 === peerId=$peerId");
    var connection = _rtcConnections[peerId];
    log("=== WebRtcConnection._requireConnection() - 2 === peerId=$peerId createNewIfAbsent=$createNewIfAbsent connection!=null => ${connection!=null}");
    if(connection == null && createNewIfAbsent) {
      connection = _rtcConnections[peerId]
        = await _initConnection(peerId: peerId, recreate: false);
    }
    log("=== WebRtcConnection._requireConnection() - 3 === peerId=$peerId createNewIfAbsent=$createNewIfAbsent _rtcConnections[$peerId]!=null => ${_rtcConnections[peerId]!=null}");
    if(connection == null) {
      throw "No RTC peer connections found with id of '$peerId'";
    }
    return connection;
  }

  void _addMediaStreamToConnection({
    required String peerId,
    required MediaStream stream,
    RTCPeerConnection? connection,
  }) {
    final usedConnection = connection ?? _rtcConnections[peerId];
    addTrackFunction(MediaStreamTrack track) {
      log("=== WebRtcConnection._addMediaStreamToConnection() peerId=$peerId track.id=${track.id}");
      log("=== WebRtcConnection._addMediaStreamToConnection() peerId=$peerId stream.id=${stream.id}");
      usedConnection!.addTrack(track, stream);
    }
    stream..onAddTrack = addTrackFunction
      ..getTracks().forEach(addTrackFunction);
  }

  void addMediaTrackFromMediaStream({
    required String peerId,
    required MediaStream stream,
    bool replaceExisting = true,
  }) {
    final streamList = _mediaStreamMap[peerId] ??= [];
    if(!replaceExisting) {
      streamList.add(stream);
    } else {
      final foundIndex = streamList.indexWhere((it) => it.id == stream.id);
      if(foundIndex > -1) {
        streamList[foundIndex] = stream;
      } else {
        streamList.add(stream);
      }
    }
    final connection = _rtcConnections[peerId];
    if(connection != null) {
      _addMediaStreamToConnection(
        peerId: peerId,
        stream: stream,
        connection: connection,
      );
    }
  }

  void _addMediaStreamToOtherConnection({
    required String srcPeerId,
    required MediaStream stream,
  }) {
    log("=== WebRtcConnection._addMediaStreamToOtherConnection() - 1 === srcPeerId=$srcPeerId stream.id=${stream.id}");

    for(final connectionPair in _rtcConnections.entries) {
      final peerId = connectionPair.key;
      log("=== WebRtcConnection._addMediaStreamToOtherConnection() - 2 === srcPeerId=$srcPeerId peerId=$peerId stream.getTracks().length=${stream.getTracks().length}");

      if(peerId == srcPeerId) {
        continue;
      }
      log("=== WebRtcConnection._addMediaStreamToOtherConnection() - 3 === srcPeerId=$srcPeerId peerId=$peerId");

      final connection = connectionPair.value;

      final existingStreamList = _mediaStreamMap[peerId] ??= [];

      final foundIndex = existingStreamList.indexWhere((it) => it.id == stream.id);
      log("=== WebRtcConnection._addMediaStreamToOtherConnection() - 4 === srcPeerId=$srcPeerId peerId=$peerId foundIndex=$foundIndex");

      if(foundIndex > -1) {
        continue;
      }

      existingStreamList.add(stream);

      _addMediaStreamToConnection(
        peerId: peerId,
        stream: stream,
        connection: connection,
      );
    }
  }

  final _onAnswerListeners = <String /*peerId*/, void Function(String peerId, bool callAccepted)>{};

  /*
   * Offering mechanism:
   * 1. Setup SDP answer listener.
   * 2. Setup ICE candidate listener so the newly created local ICE candidate can be caught.
   * 3. Offer the SDP.
   */
  Future<void> doOfferingProcedure({
    required Iterable<String> peerIdList,
    Map<String, dynamic>? constraints,
    Map<String, dynamic>? offerExtraData,
    bool forwardCallToOtherPeers = true,
    void Function(String peerId, bool callAccepted)? onAnswer,
  }) async {
    log("=== WebRtcConnection.doOfferingProcedure() - 1 === peerIdList=$peerIdList offerExtraData=$offerExtraData");

    onAnswerListener(String innerPeerId, bool callAccepted) {
      log("=== WebRtcConnection.doOfferingProcedure._listenForSdpAnswer() innerPeerId=$innerPeerId callAccepted=$callAccepted forwardCallToOtherPeers=$forwardCallToOtherPeers");
      log("=== WebRtcConnection.doOfferingProcedure._listenForSdpAnswer() innerPeerId=$innerPeerId callAccepted=$callAccepted _registeredPeerIdList=$_registeredPeerIdList");
      if(callAccepted) {
        _registeredPeerIdList.add(innerPeerId);
        /*
          final newOffer = await (await _requireConnection(innerPeerId)).createOffer();
          log("=== WebRtcConnection.doOfferingProcedure._listenForSdpAnswer().callAccepted callAccepted=$callAccepted newOffer=${newOffer.toMap()}");
           */
        _sendIceCandidate(peerId: innerPeerId);
        if(forwardCallToOtherPeers) {
          _sendPeerIdListToConnect(
            peerId: innerPeerId,
            peerIdListToConnectTo: _registeredPeerIdList,
          );
        }
      } else {
        _stopConnection(peerId: innerPeerId);
      }
      onAnswer?.call(innerPeerId, callAccepted);
    }

    for(final peerId in peerIdList) {
      _onAnswerListeners[peerId] = onAnswerListener;
    }

    final newPeerIdSet = peerIdList.toSet()
        .where((it) => it != localId && !_registeredPeerIdList.contains(it));
    log("=== WebRtcConnection.doOfferingProcedure() - 2 === peerIdList=$peerIdList newPeerIdSet=$newPeerIdSet _registeredPeerIdList=$_registeredPeerIdList");
    for(final peerId in newPeerIdSet) {
      await _sdpOffer(
        peerId: peerId,
        constraints: constraints,
        extraData: offerExtraData,
      );
    }
    log("=== WebRtcConnection.doOfferingProcedure() - 3 === peerIdList=$peerIdList newPeerIdSet=$newPeerIdSet");
  }

  void prepareAsCallee({
    void Function(String peerId, Map<String, dynamic> data)? onOffered
  }) {
    _listenForSdpOffer();
    _receiveIceCandidate();
  }

  void stopBeingCallee() {
    // _listenForSdpOffer(onOffered: null);
    _commChannel.listenSdpOffer(null);
    _stopReceivingIceCandidate();
  }

  /*
  Future<RTCSessionDescription> _initInitialSdpOffer([Map<String, dynamic>? constraints]) async {
    log("=== WebRtcConnection._initInitialSdpOffer() ===");
    final initConnection = _initialConnection ??= await _createInitialConnection();
    final localMediaStream = _localMediaStream;
    localMediaStream?.getTracks().forEach((track) {
      initConnection.addTrack(track, localMediaStream);
    });
    return _initialSdpOffer ??= await initConnection.createOffer(constraints ?? {});
  }
   */

  Future<void> _sdpOffer({
    required String peerId,
    Map<String, dynamic>? constraints,
    Map<String, dynamic>? extraData,
  }) async {
    log("=== WebRtcConnection._sdpOffer() - 1 === peerId=$peerId constraints=$constraints");
    final connection = await _requireConnection(peerId, createNewIfAbsent: true);
    log("=== WebRtcConnection._sdpOffer() - 2 === peerId=$peerId");
    var offering = await connection.createOffer(constraints ?? {});
    log("=== WebRtcConnection._sdpOffer() - 3 === peerId=$peerId offering.toMap()=${offering.toMap()}");
    await connection.setLocalDescription(offering);
    log("=== WebRtcConnection._sdpOffer() - 4 === peerId=$peerId");
    _commChannel.emitSdpOffer(
      receiverId: peerId,
      offer: offering.toMap(),
      extraData: extraData,
    );
    /*
    // TODO: DELETE COMMENTED CODE!!!
    _commChannel.emit(
        eventSdpOffer,
        {
          keySenderDeviceId : localDeviceId,
          keySenderId : localId,
          keyReceiverId : peerId,
          "sdpOffer" : offering.toMap(),
          if(extraData != null)
            keyExtraData : extraData,
        }
      );
     */
  }

  _listenForSdpOffer({void Function(String peerId, Map<String, dynamic> data)? onOffered}) {
    _commChannel.listenSdpOffer((peerId, sdpOffer, extraData) async {
      setRemoteSdpFromMap(peerId: peerId, sdpData: sdpOffer);
      final bool forceAcceptCall = extraData?[WebRtcChannel.keyForceAccept] ?? false;
      if(forceAcceptCall) {
        _sdpAnswer(peerId: peerId, acceptCall: true);
      }
    });

    /*
    // TODO: DELETE COMMENTED CODE!!!
    _commChannel.listen(eventSdpOffer, (data) async {
      final String peerId = data[keySenderId]; //keySenderDeviceId
      final sdpOffer = data[keySdpOffer];
      setRemoteSdpFromMap(peerId: peerId, sdpData: sdpOffer);
      final bool forceAcceptCall = data[keyExtraData]?[keyForceAccept] ?? false;
      if(forceAcceptCall) {
        _sdpAnswer(peerId: peerId, acceptCall: true);
      }
      onOffered?.call(peerId, data);
    });
     */
  }

  /// Tells [peerId] to connect to [peerIdListToConnectTo].
  _sendPeerIdListToConnect({
    required String peerId,
    required Iterable<String> peerIdListToConnectTo,
  }) {
    log("=== WebRtcConnection._sendPeerIdListToConnect() - 1 - peerId=$peerId peerIdListToConnectTo=$peerIdListToConnectTo");
    log("=== WebRtcConnection._sendPeerIdListToConnect() - 1.2 - peerId=$peerId stacktrace=${StackTrace.current}");

    final filteredPeerIdListToConnect = peerIdListToConnectTo
        .where((it) => it != peerId)
        .toList();

    log("=== WebRtcConnection._sendPeerIdListToConnect() - 2 - peerId=$peerId filteredPeerIdListToConnect=$filteredPeerIdListToConnect");
    if(filteredPeerIdListToConnect.isEmpty) {
      return;
    }
    _commChannel.emitPeerListToConnect(
        receiverId: peerId,
        remotePeerIdList: filteredPeerIdListToConnect,
    );
    /*
    // TODO: DELETE COMMENTED CODE!!!
    _commChannel.emit(
      eventPeerListToConnect,
      {
        keySenderDeviceId : localDeviceId,
        keySenderId : localId,
        keyReceiverId : peerId,
        keyPeerIdList : filteredPeerIdListToConnect,
      }
    );
     */
  }

  _listenForPeerIdListToConnect() {
    _commChannel.listenPeerListToConnect((senderId, peerIdList) async {
      log("=== WebRtcConnection._listenForPeerIdListToConnect.listen() - 2 === peerIdList=$peerIdList");
      await doOfferingProcedure(
        peerIdList: peerIdList,
        offerExtraData: {
          WebRtcChannel.keyForceAccept : true,
        },
        forwardCallToOtherPeers: false,
      );
      log("=== WebRtcConnection._listenForPeerIdListToConnect.listen() - 3 === peerIdList=$peerIdList");
    });
    /*
    // TODO: DELETE COMMENTED CODE!!!
    _commChannel.listen(
      eventPeerListToConnect,
      (data) async {
        log("=== WebRtcConnection._listenForPeerIdListToConnect.listen() - 1 === data=$data");

        final Iterable<String> peerIdList = (data[keyPeerIdList] as List).map((it) => it.toString());

        log("=== WebRtcConnection._listenForPeerIdListToConnect.listen() - 2 === peerIdList=$peerIdList");
        await doOfferingProcedure(
          peerIdList: peerIdList,
          offerExtraData: {
            keyForceAccept : true,
          },
          forwardCallToOtherPeers: false,
        );
        log("=== WebRtcConnection._listenForPeerIdListToConnect.listen() - 3 === peerIdList=$peerIdList");
      }
    );
     */
  }

  Future<void> answerCall({
    required String peerId,
    bool acceptCall = true,
    Map<String, String>? offeringAnswerData,
    bool createNewConnection = true,
  }) => _sdpAnswer(
    peerId: peerId,
    acceptCall: acceptCall,
    offeringAnswerData: offeringAnswerData,
    createNewConnection: createNewConnection,
  );

  Future<void> _sdpAnswer({
    required String peerId,
    bool acceptCall = true,
    Map<String, String>? offeringAnswerData,
    bool createNewConnection = true,
  }) async {
    log("=== WebRtcConnection._sdpAnswer() - 1 ===");

    RTCSessionDescription? sdpAnswer;
    if(acceptCall) {
      final connection = await _requireConnection(peerId, createNewIfAbsent: createNewConnection);
      sdpAnswer =
          offeringAnswerData != null
              ? RTCSessionDescription(
                offeringAnswerData["sdp"],
                offeringAnswerData["type"],
              )
              : await connection.createAnswer()
      ;
      log("=== WebRtcConnection._sdpAnswer() - 2 ===");

      // set SDP answer as localDescription for peerConnection
      await connection.setLocalDescription(sdpAnswer);

      _registeredPeerIdList.add(peerId);
    }
    log("=== WebRtcConnection._sdpAnswer() - 3 ===");

    _commChannel.emitSdpAnswer(
        receiverId: peerId,
        acceptCall: acceptCall,
        answer: sdpAnswer?.toMap(),
    );
    /*
    // TODO: DELETE COMMENTED CODE!!!
    _commChannel.emit(
      eventSdpAnswer,
      {
        keySenderDeviceId : localDeviceId,
        keySenderId : localId,
        keyReceiverId : peerId,
        keyAcceptCall : acceptCall,
        if(sdpAnswer != null)
          "sdpAnswer" : sdpAnswer.toMap(),
      },
    );
     */
    log("=== WebRtcConnection._sdpAnswer() - 4 ===");
  }

  _listenForSdpAnswer() {
    log("=== WebRtcConnection._listenForSdpAnswer() - 1 ===");
    _commChannel.listenSdpAnswer((peerId, callAccepted, sdpAnswer) async {
      final onAnswer = _onAnswerListeners[peerId];
      if(!callAccepted) {
        onAnswer?.call(peerId, callAccepted);
        return;
      }
      //await _initConnection(peerId: peerId, recreate: false);
      setRemoteSdpFromMap(peerId: peerId, sdpData: sdpAnswer);
      onAnswer?.call(peerId, callAccepted);
    });
    /*
    // TODO: DELETE COMMENTED CODE!!!
    _commChannel.listen(eventSdpAnswer, (data) async {
      log("=== WebRtcConnection._listenForSdpAnswer.listen() - 2 === data=$data");
      bool callAccepted = data[keyAcceptCall];
      final String peerId = data[keySenderId]; //keySenderDeviceId
      final onAnswer = _onAnswerListeners[peerId];
      if(!callAccepted) {
        log("=== WebRtcConnection._listenForSdpAnswer.listen() - 3 === data=$data");
        onAnswer?.call(peerId, callAccepted);
        return;
      }
      log("=== WebRtcConnection._listenForSdpAnswer.listen() - 4 === data=$data");
      final sdpAnswer = data[keySdpAnswer];
      //await _initConnection(peerId: peerId, recreate: false);
      setRemoteSdpFromMap(peerId: peerId, sdpData: sdpAnswer);
      onAnswer?.call(peerId, callAccepted);
      log("=== WebRtcConnection._listenForSdpAnswer.listen() - 5 === data=$data");
    });
     */
  }

  void _attachOnIceCandidateListener({
    required String peerId,
  }) {
    final connection = _rtcConnections[peerId];
    log("=== WebRtcConnection._attachOnIceCandidateListener() - 0 === connection != null => ${connection != null}");
    connection?.onIceCandidate = (RTCIceCandidate candidate) {
      log("=== WebRtcConnection._attachOnIceCandidateListener.onIceCandidate() - 1 ===");
      final iceCandidateList = _localIceCandidateMap[peerId] ??= [];
      if(iceCandidateList.any((it) => it.sdpMid == candidate.sdpMid)) {
        log("=== WebRtcConnection._attachOnIceCandidateListener.onIceCandidate() - 2 - RETURN!!! ===");
        return;
      }
      log("=== WebRtcConnection._attachOnIceCandidateListener.onIceCandidate() - 3 ===");
      iceCandidateList.add(candidate);
      log("=== WebRtcConnection._attachOnIceCandidateListener.onIceCandidate() - 4 ===");
    };
  }

  _sendIceCandidate({
    required String peerId,
    List<RTCIceCandidate>? iceCandidateList,
  }) {
    log("=== WebRtcConnection._sendIceCandidate() - 1 === peerId=$peerId");
    final usedIceCandidateList = iceCandidateList ?? (_localIceCandidateMap[peerId] ??= []);
    log("=== WebRtcConnection._sendIceCandidate() - 2 === peerId=$peerId usedIceCandidateList.length=${usedIceCandidateList.length}");
    for (var iceCandidate in usedIceCandidateList) {
      _commChannel.emitIceCandidate(
          receiverId: peerId,
          id: iceCandidate.sdpMid,
          label: iceCandidate.sdpMLineIndex?.toString(),
          candidate: iceCandidate.candidate,
      );
      /*
    // TODO: DELETE COMMENTED CODE!!!
      _commChannel.emit(
        eventIceCandidate,
        {
          keySenderDeviceId : localDeviceId,
          keySenderId : localId,
          keyReceiverId : peerId,
          keyIceCandidate : {
            "id": iceCandidate.sdpMid,
            "label": iceCandidate.sdpMLineIndex,
            "candidate": iceCandidate.candidate,
          },
        },
      );
       */
    }
  }

  _receiveIceCandidate() {
    _commChannel.listenIceCandidate((peerId, id, label, candidate) async {
      final newCandidate = RTCIceCandidate(
        candidate,
        id,
        label != null ? int.parse(label) : null,
      );

      //(_localIceCandidateMap[peerId] ??= []).add(newCandidate);
      (await _requireConnection(peerId, createNewIfAbsent: true))
          .addCandidate(newCandidate);
    });
    /*
    // TODO: DELETE COMMENTED CODE!!!
    _commChannel.listen(eventIceCandidate, (data) async {
      log("=== WebRtcConnection._receiveIceCandidate() - 1 ===");
      final peerId = data[keySenderId]; //keySenderDeviceId
      final candidate = data[keyIceCandidate];
      log("=== WebRtcConnection._receiveIceCandidate() - 2 === peerId=$peerId");
      String candidateStr = candidate["candidate"];
      String sdpMid = candidate["id"];
      int sdpMLineIndex = candidate["label"];

      final newCandidate = RTCIceCandidate(
        candidateStr,
        sdpMid,
        sdpMLineIndex,
      );

      //(_localIceCandidateMap[peerId] ??= []).add(newCandidate);
      (await _requireConnection(peerId, createNewIfAbsent: true))
          .addCandidate(newCandidate);
    });
     */
  }

  _stopReceivingIceCandidate() {
    _commChannel.listenIceCandidate(null);
    // TODO: DELETE COMMENTED CODE!!!
    //_commChannel.listen(eventIceCandidate, null);
  }

  stopCallWithPeer({required String peerId}) {
    _commChannel.emitStopCall(receiverId: peerId);
    /*
    // TODO: DELETE COMMENTED CODE!!!
    _commChannel.emit(
        eventStopCall,
        {
          keySenderDeviceId : localDeviceId,
          keySenderId : localId,
          keyReceiverId : peerId,
        },
    );
     */
    _stopConnection(peerId: peerId);
  }

  /// Stop call with all remote peers
  leaveCall() {
    final registeredPeerIdList = _registeredPeerIdList.toSet();
    log("=== WebRtcConnection.leaveCall() - 1 === registeredPeerIdList=$registeredPeerIdList");
    for(final peerId in registeredPeerIdList) {
      stopCallWithPeer(peerId: peerId);
    }
    log("=== WebRtcConnection.leaveCall() - 2 === _registeredPeerIdList=$_registeredPeerIdList");
  }

  endCall() {
    final registeredPeerIdList = _registeredPeerIdList.toSet();
    for(final peerId in registeredPeerIdList) {
      _commChannel.emitEndCall(receiverId: peerId, extraData: {WebRtcChannel.keyForceAccept : true});
      /*
    // TODO: DELETE COMMENTED CODE!!!
      _commChannel.emit(
        eventEndCall,
        {
          keySenderDeviceId : localDeviceId,
          keySenderId : localId,
          keyReceiverId : peerId,
        },
      );
       */
    }
    _disposeConnections();
  }

  _disposeConnections() {
    //_disposeInitialConnection();
    //_initialSdpOffer = null;
    _rtcConnections.values.forEach((it) => it.dispose());
    _mediaStreamMap.values.forEach((list) => list.forEach((it) => it.dispose()));
    _localIceCandidateMap.clear();
    _registeredPeerIdList.clear();
  }

  _listenToEndCallEvent() {
    _commChannel.listenEndCall((senderId, extraData) {
      final bool forceAcceptToEndCall = extraData?[WebRtcChannel.keyForceEnd] ?? false;
      if(forceAcceptToEndCall) {
        dispose();
        _onEndCall?.call();
      }
    });
    /*
    // TODO: DELETE COMMENTED CODE!!!
    _commChannel.listen(
      eventEndCall,
      (data) {
        final bool forceAcceptToEndCall = data[keyExtraData]?[keyForceAccept] ?? false;
        if(forceAcceptToEndCall) {
          dispose();
          _onEndCall?.call();
        }
      }
    );
     */
  }

  _stopConnection({
    required String peerId,
    bool removeRegistry = true
  }) {
    if(removeRegistry) {
      _rtcConnections.remove(peerId)?.dispose();
      _localIceCandidateMap.remove(peerId);
      _mediaStreamMap.remove(peerId)?.forEach((it) => it.dispose());
      _registeredPeerIdList.remove(peerId);
    } else {
      _rtcConnections[peerId]?.dispose();
      _mediaStreamMap[peerId]?.forEach((it) => it.dispose());
    }
    _onStopCall?.call(peerId);
  }

  _listenToStopCallEvent() {
    _commChannel.listenStopCall((peerId) {
      _stopConnection(peerId: peerId);
    });
    /*
    // TODO: DELETE COMMENTED CODE!!!
    _commChannel.listen(
      eventStopCall,
      (data) {
      }
    );
     */
  }

  /*
  void _disposeInitialConnection() {
    _initialConnection?.dispose();
    _initialConnection = null;
  }
   */

  void dispose() {
    _disposeConnections();
    for(final senderList in _localMediaTrackSenders.values) {
      for(final sender in senderList) {
        sender.dispose();
      }
    }
    _commChannel
      ..listenSdpOffer(null)
      ..listenSdpAnswer(null)
      ..listenIceCandidate(null)
    ;
  }
}