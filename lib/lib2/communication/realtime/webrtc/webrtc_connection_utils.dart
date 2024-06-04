import 'package:cob_duplication_flutter_webrtc/lib2/communication/channel/socket_io_channel.dart';
import 'package:cob_duplication_flutter_webrtc/lib2/communication/realtime/webrtc/webrtc_connection.dart';
import 'package:cob_duplication_flutter_webrtc/lib2/communication/realtime/webrtc/webrtc_connection_multi.dart';
import 'package:socket_io_client/socket_io_client.dart';

class WebRtcConnectionUtils {
  WebRtcConnectionUtils._();

  static WebRtcConnectionManager getConnectionFromSocketIo({
    required Socket socket,
    required String localId,
    required String peerId,
    required String localDeviceId,
  }) => WebRtcConnectionManager(
    commChannel: SocketIoChannel(socket),
    localId: localId,
    peerId: peerId,
    localDeviceId: localDeviceId,
  );

  static WebRtcConnectionManagerMulti getConnectionFromSocketIo_multi({
    required Socket socket,
    required String localId,
    required String localDeviceId,
  }) => WebRtcConnectionManagerMulti(
    commChannel: SocketIoChannel(socket),
    localId: localId,
    localDeviceId: localDeviceId,
  );
}