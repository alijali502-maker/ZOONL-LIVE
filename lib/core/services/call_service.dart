import 'package:livekit_client/livekit_client.dart';

class CallService {
  Room? _room;

  Room? get room => _room;

  Future<void> joinCall({
    required String serverUrl,
    required String participantToken,
    bool video = true,
  }) async {
    final room = Room();

    await room.connect(serverUrl, participantToken);
    await room.localParticipant?.setMicrophoneEnabled(true);

    if (video) {
      await room.localParticipant?.setCameraEnabled(true);
    }

    _room = room;
  }

  Future<void> toggleMicrophone(bool enabled) async {
    await _room?.localParticipant?.setMicrophoneEnabled(enabled);
  }

  Future<void> toggleCamera(bool enabled) async {
    await _room?.localParticipant?.setCameraEnabled(enabled);
  }

  Future<void> leaveCall() async {
    await _room?.disconnect();
    _room = null;
  }
}