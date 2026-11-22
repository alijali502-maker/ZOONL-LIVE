
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import 'services/call_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String serverUrl;
  final String participantToken;
  final String participantName;
  final CallService callService;

  const VideoCallScreen({
    super.key,
    required this.serverUrl,
    required this.participantToken,
    required this.callService,
    this.participantName = 'Participant',
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  Room? _room;

  bool _connecting = true;
  bool _ending = false;
  bool _microphoneEnabled = true;
  bool _cameraEnabled = true;

  String? _error;

  @override
  void initState() {
    super.initState();
    _connectCall();
  }

  Future<void> _connectCall() async {
    try {
      final room = await widget.callService.joinCall(
        serverUrl: widget.serverUrl,
        participantToken: widget.participantToken,
        video: true,
      );

      if (!mounted) {
        await widget.callService.leaveCall();
        return;
      }

      _room = room;
      room.addListener(_onRoomChanged);

      setState(() {
        _connecting = false;
        _microphoneEnabled = true;
        _cameraEnabled = true;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _connecting = false;
        _error = e.toString();
      });
    }
  }

  void _onRoomChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleMicrophone() async {
    try {
      final nextValue = !_microphoneEnabled;

      await widget.callService.toggleMicrophone(nextValue);

      if (!mounted) return;

      setState(() {
        _microphoneEnabled = nextValue;
      });
    } catch (e) {
      _showMessage('Microphone error: $e');
    }
  }

  Future<void> _toggleCamera() async {
    try {
      final nextValue = !_cameraEnabled;

      await widget.callService.toggleCamera(nextValue);

      if (!mounted) return;

      setState(() {
        _cameraEnabled = nextValue;
      });
    } catch (e) {
      _showMessage('Camera error: $e');
    }
  }

  Future<void> _endCall() async {
    if (_ending) return;

    setState(() => _ending = true);

    try {
      _room?.removeListener(_onRoomChanged);
      await widget.callService.leaveCall();
    } catch (e) {
      _showMessage('Call ending error: $e');
    }

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _participantVideo(dynamic participant) {
    try {
      for (final publication in participant.videoTrackPublications) {
        final track = publication.track;

        if (track is VideoTrack) {
          return VideoTrackRenderer(
            track,
            fit: VideoViewFit.cover,
          );
        }
      }
    } catch (_) {
      // Show placeholder if video is unavailable.
    }

    return _videoPlaceholder(
      participant.name?.toString() ?? 'Participant',
    );
  }

  Widget _videoPlaceholder(String name) {
    return Container(
      color: const Color(0xFF21152F),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 42,
              backgroundColor: Color(0xFF49305E),
              child: Icon(
                Icons.person,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Camera is off',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteVideos() {
    final room = _room;

    if (room == null || room.remoteParticipants.isEmpty) {
      return const Center(
        child: Text(
          'Waiting for the other participant...',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final participants = room.remoteParticipants.values.toList();

    return GridView.builder(
      padding: const EdgeInsets.all(6),
      itemCount: participants.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: participants.length == 1 ? 1 : 2,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: participants.length == 1 ? 0.75 : 0.85,
      ),
      itemBuilder: (context, index) {
        final participant = participants[index];

        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _participantVideo(participant),
              Positioned(
                left: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    participant.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocalVideo() {
    final room = _room;
    final localParticipant = room?.localParticipant;

    if (localParticipant == null || !_cameraEnabled) {
      return _videoPlaceholder('You');
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: _participantVideo(localParticipant),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color color = const Color(0xFF39234D),
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white),
          style: IconButton.styleFrom(
            backgroundColor: color,
            fixedSize: const Size(56, 56),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _room?.removeListener(_onRoomChanged);
    unawaited(widget.callService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF100B18),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.videocam,
                    color: Color(0xFFE5BD70),
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'ZOONL VIDEO CALL',
                      style: TextStyle(
                        color: Color(0xFFE5BD70),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!_connecting && _error == null)
                    const Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 9,
                          color: Colors.green,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Connected',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            Expanded(
              child: _connecting
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: Color(0xFFE5BD70),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Connecting to video call...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.redAccent,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Unable to connect',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: _endCall,
                                  child: const Text('Go Back'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Stack(
                          children: [
                            Positioned.fill(
                              child: _buildRemoteVideos(),
                            ),
                            Positioned(
                              right: 14,
                              top: 14,
                              width: 115,
                              height: 160,
                              child: _buildLocalVideo(),
                            ),
                          ],
                        ),
            ),

            if (!_connecting && _error == null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 18,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF1B1225),
                  border: Border(
                    top: BorderSide(color: Color(0xFF49305E)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _controlButton(
                      icon: _microphoneEnabled
                          ? Icons.mic
                          : Icons.mic_off,
                      label: _microphoneEnabled ? 'Mute' : 'Unmute',
                      onPressed: _toggleMicrophone,
                      color: _microphoneEnabled
                          ? const Color(0xFF39234D)
                          : Colors.redAccent,
                    ),
                    _controlButton(
                      icon: _cameraEnabled
                          ? Icons.videocam
                          : Icons.videocam_off,
                      label: _cameraEnabled ? 'Camera On' : 'Camera Off',
                      onPressed: _toggleCamera,
                      color: _cameraEnabled
                          ? const Color(0xFF39234D)
                          : Colors.redAccent,
                    ),
                    _controlButton(
                      icon: Icons.call_end,
                      label: 'End Call',
                      onPressed: _endCall,
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
