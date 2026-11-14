
import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

class CallService {
  Room? _room;
  bool _isConnecting = false;

  Room? get room => _room;

  bool get isConnected => _room != null;

  bool get isConnecting => _isConnecting;

  Future<Room> joinCall({
    required String serverUrl,
    required String participantToken,
    bool video = true,
  }) async {
    if (_isConnecting) {
      throw StateError('A call connection is already in progress.');
    }

    if (serverUrl.trim().isEmpty ||
        participantToken.trim().isEmpty) {
      throw ArgumentError('Server URL and participant token are required.');
    }

    if (_room != null) {
      await leaveCall();
    }

    _isConnecting = true;
    final newRoom = Room();

    try {
      await newRoom.connect(
        serverUrl.trim(),
        participantToken.trim(),
      );

      await newRoom.localParticipant?.setMicrophoneEnabled(true);

      if (video) {
        await newRoom.localParticipant?.setCameraEnabled(true);
      }

      _room = newRoom;
      return newRoom;
    } catch (_) {
      try {
        await newRoom.disconnect();
      } catch (_) {
        // Preserve the original connection error.
      }
      rethrow;
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> toggleMicrophone(bool enabled) async {
    final currentRoom = _room;
    if (currentRoom == null) {
      throw StateError('You are not connected to a call.');
    }

    await currentRoom.localParticipant?.setMicrophoneEnabled(enabled);
  }

  Future<void> toggleCamera(bool enabled) async {
    final currentRoom = _room;
    if (currentRoom == null) {
      throw StateError('You are not connected to a call.');
    }

    await currentRoom.localParticipant?.setCameraEnabled(enabled);
  }

  Future<void> leaveCall() async {
    final currentRoom = _room;
    _room = null;

    if (currentRoom != null) {
      await currentRoom.disconnect();
    }
  }

  Future<void> dispose() async {
    await leaveCall();
  }
}
