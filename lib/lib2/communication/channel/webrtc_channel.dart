import 'package:cob_duplication_flutter_webrtc/lib2/communication/channel/channels.dart';
import 'package:cob_duplication_flutter_webrtc/lib2/communication/channel/socket_io_channel.dart';


abstract class WebRtcChannel implements InOutChannel<Map<String, dynamic>> {
  static const String eventSdpOffer = "sdp_offer";
  static const String eventSdpAnswer = "sdp_answer";
  static const String eventIceCandidate = "ice_candidate";
  /// Stop call with a particular remote peer
  static const String eventStopCall = "stop_call";
  /// Instructs to remote peer to end call
  static const String eventEndCall = "end_call";
  static const String eventPeerListToConnect = "peer_list_to_connect";

  static const String keyClientId = "clientId";
  static const String keySenderId = "senderId";
  static const String keyReceiverId = "receiverId";
  static const String keySdpOffer = "sdpOffer";
  static const String keySdpAnswer = "sdpAnswer";
  static const String keyAcceptCall = "acceptCall";
  static const String keyIceCandidate = "iceCandidate";
  static const String keySenderDeviceId = "senderDeviceId";
  static const String keyPeerIdList = "peerIdList";
  static const String keyExtraData = "extraData";
  static const String keyForceAccept = "forceAccept"; // TODO: Needs an extra security layer
  static const String keyForceEnd = "forceEnd"; // TODO: Needs an extra security layer


  final String _localDeviceId;
  final String _localPeerId;

  WebRtcChannel(this._localDeviceId, this._localPeerId);

  factory WebRtcChannel.fromSocketIo({
    required SocketIoChannel channel,
    required String localDeviceId,
    required String localPeerId,
  }) => _WebRtcSocketIoChannel(localDeviceId, localPeerId, channel);


  Map<String, String> _getDefaultEmissionData(String receiverId) => {
    keySenderDeviceId : _localDeviceId,
    keySenderId : _localPeerId,
    keyReceiverId : receiverId,
  };

  void emitSdpOffer({
    required String receiverId,
    required Map<String, dynamic> offer,
    Map<String, dynamic>? extraData,
  });
  void listenSdpOffer(
    void Function(
      String senderId,
      Map<String, dynamic> offer,
      Map<String, dynamic>? extraData,
    )? onOffer
  );

  void emitSdpAnswer({
    required String receiverId,
    required bool acceptCall,
    Map<String, dynamic>? answer,
  });
  void listenSdpAnswer(
    void Function(
      String senderId,
      bool acceptCall,
      Map<String, dynamic>? answer,
    )? onAnswer,
  );

  void emitIceCandidate({
    required String receiverId,
    required String? id,
    required String? label,
    required String? candidate,
  });
  void listenIceCandidate(
    void Function(
      String senderId,
      String? id,
      String? label,
      String? candidate,
    )? onIceCandidate,
  );

  void emitStopCall({
    required String receiverId,
  });
  void listenStopCall(
    void Function(
      String senderId,
    )? onStopCall,
  );

  void emitEndCall({
    required String receiverId,
    Map<String, dynamic>? extraData,
  });
  void listenEndCall(
    void Function(
      String senderId,
      Map<String, dynamic>? extraData,
    )? onEndCall,
  );

  void emitPeerListToConnect({
    required String receiverId,
    required Iterable<String> remotePeerIdList,
  });
  void listenPeerListToConnect(
    void Function(
      String senderId,
      Iterable<String> remotePeerIdList,
    )? onPeerList
  );


}



abstract class _WebRtcChannelBase extends WebRtcChannel {
  _WebRtcChannelBase(super.localDeviceId, super.localPeerId);

  void _standardEmit(String event, String receiverId, [Map<String, dynamic>? data]) {
    emit(event, {
      ..._getDefaultEmissionData(receiverId),
      if(data != null)
        ...data,
    });
  }

  @override
  void emitEndCall({required String receiverId, Map<String, dynamic>? extraData}) =>
      _standardEmit(WebRtcChannel.eventEndCall, receiverId);

  @override
  void emitIceCandidate({
    required String receiverId,
    required String? id,
    required String? label,
    required String? candidate,
  }) => _standardEmit(
    WebRtcChannel.eventIceCandidate,
    receiverId,
    {
      WebRtcChannel.keyIceCandidate : {
        "id": id,
        "label": label,
        "candidate": candidate,
      },
    }
  );

  @override
  void emitPeerListToConnect({required String receiverId, required Iterable<String> remotePeerIdList}) =>
      _standardEmit(
        WebRtcChannel.eventPeerListToConnect,
        receiverId,
        {
          WebRtcChannel.keyPeerIdList : remotePeerIdList.toList(),
        }
      );

  @override
  void emitSdpAnswer({
    required String receiverId,
    required bool acceptCall,
    Map<String, dynamic>? answer,
  }) =>
      _standardEmit(
        WebRtcChannel.eventSdpAnswer,
        receiverId,
        {
          WebRtcChannel.keyAcceptCall : acceptCall,
          if(answer != null)
            WebRtcChannel.keySdpAnswer : answer
        }
      );

  @override
  void emitSdpOffer({
    required String receiverId,
    required Map<String, dynamic> offer,
    Map<String, dynamic>? extraData,
  }) => _standardEmit(
    WebRtcChannel.eventSdpOffer,
    receiverId,
    {
      WebRtcChannel.keySdpOffer : offer,
      if(extraData != null)
        WebRtcChannel.keyExtraData : extraData,
    }
  );

  @override
  void emitStopCall({required String receiverId}) =>
      _standardEmit(WebRtcChannel.eventStopCall, receiverId);

  @override
  void listenEndCall(void Function(String senderId, Map<String, dynamic>? extraData)? onStopCall) =>
      listen(WebRtcChannel.eventEndCall, (data) {
        onStopCall?.call(
          data[WebRtcChannel.keySenderId],
          data[WebRtcChannel.keyExtraData],
        );
      });

  @override
  void listenStopCall(void Function(String senderId)? onEndCall) =>
      listen(WebRtcChannel.eventStopCall, (data) {
        onEndCall?.call(
            data[WebRtcChannel.keySenderId]
        );
      });

  @override
  void listenIceCandidate(void Function(String senderId, String? id, String? label, String? candidate)? onIceCandidate) =>
      listen(WebRtcChannel.eventIceCandidate, (data) {
        onIceCandidate?.call(
            data[WebRtcChannel.keySenderId],
            data[WebRtcChannel.keyIceCandidate]["id"],
            data[WebRtcChannel.keyIceCandidate]["label"],
            data[WebRtcChannel.keyIceCandidate]["candidate"],
        );
      });

  @override
  void listenPeerListToConnect(void Function(String senderId, Iterable<String> remotePeerIdList)? onPeerList) =>
      listen(WebRtcChannel.eventPeerListToConnect, (data) {
        onPeerList?.call(
          data[WebRtcChannel.keySenderId],
          (data[WebRtcChannel.keyPeerIdList] as List).map((it) => it.toString()),
        );
      });

  @override
  void listenSdpAnswer(void Function(String senderId, bool acceptCall, Map<String, dynamic>? answer)? onAnswer) =>
      listen(WebRtcChannel.eventSdpAnswer, (data) {
        onAnswer?.call(
          data[WebRtcChannel.keySenderId],
          data[WebRtcChannel.keyAcceptCall],
          data[WebRtcChannel.keySdpAnswer],
        );
      });

  @override
  void listenSdpOffer(void Function(String senderId, Map<String, dynamic> offer, Map<String, dynamic>? extraData)? onOffer) =>
      listen(WebRtcChannel.eventSdpOffer, (data) {
        onOffer?.call(
          data[WebRtcChannel.keySenderId],
          data[WebRtcChannel.keySdpOffer],
          data[WebRtcChannel.keyExtraData],
        );
      });
}

class _WebRtcSocketIoChannel extends _WebRtcChannelBase {
  final SocketIoChannel _commChannel;

  _WebRtcSocketIoChannel(
    super.localDeviceId,
    super.localPeerId,
    this._commChannel,
  );


  @override
  void emit(String event, Map<String, dynamic> data) => _commChannel.emit(event, data);

  @override
  void listen(String event, void Function(Map<String, dynamic> p1)? onData) =>
      _commChannel.listen(event, (dynData) => onData?.call(dynData));
}