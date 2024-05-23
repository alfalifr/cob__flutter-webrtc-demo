import 'package:cob_duplication_flutter_webrtc/lib2/communication/channel/socket_io_channel.dart';
import 'package:cob_duplication_flutter_webrtc/lib2/communication/realtime/webrtc/webrtc_connection.dart';
import 'package:socket_io_client/socket_io_client.dart';

class WebRtcConnectionUtils {
  WebRtcConnectionUtils._();

  static WebRtcConnection getConnectionFromSocketIo({
    required Socket socket,
    required String roomId,
  }) => WebRtcConnection(
    commChannel: SocketIoChannel(socket),
    roomId: roomId,
  );
}