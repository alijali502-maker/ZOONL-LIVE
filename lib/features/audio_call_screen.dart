
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../core/call_service.dart';

class AudioCallScreen extends StatefulWidget {
  final String serverUrl;
  final String participantToken;
  final String participantName;
  final CallService callService;

  const AudioCallScreen({
    super.key,
    required this.serverUrl,
    required this.participantToken,
    required this.callService,
    this.participantName = 'Participant',
  });

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  Room? _room;

  bool _connecting = true;
  bool _ending = false;
  bool _microphoneEnabled = true;

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
        video: false,
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

  Future<void> _endCall() async {
    if (_ending) return;

    setState(() => _ending = true);

    try {
      _room?.removeListener(_onRoomChanged);
      await widget.callService.leaveCall();
    } catch (e) {
      _showMessage('Unable to end call: $e');
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

  @override
  void dispose() {
    _room?.removeListener(_onRoomChanged);
    unawaited(widget.callService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remoteCount = _room?.remoteParticipants.length ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF100B18),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.headphones,
                    color: Color(0xFFE5BD70),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'ZOONL AUDIO CALL',
                      style: TextStyle(
                        color: Color(0xFFE5BD70),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
                        SizedBox(width: 6),
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
              child: Center(
                child: _connecting
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: Color(0xFFE5BD70),
                          ),
                          SizedBox(height: 18),
                          Text(
                            'Connecting audio call...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      )
                    : _error != null
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.redAccent,
                                  size: 52,
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Unable to connect',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 10),
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
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF6E3B8F),
                                      Color(0xFF291638),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: const Color(0xFFE5BD70),
                                    width: 2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x554F286D),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 85,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                widget.participantName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                remoteCount > 0
                                    ? 'Participant connected'
                                    : 'Waiting for participant...',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF291D35),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _microphoneEnabled
                                          ? Icons.mic
                                          : Icons.mic_off,
                                      color: _microphoneEnabled
                                          ? Colors.greenAccent
                                          : Colors.redAccent,
                                      size: 17,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _microphoneEnabled
                                          ? 'Microphone On'
                                          : 'Microphone Muted',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
              ),
            ),

            if (!_connecting && _error == null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF1B1225),
                  border: Border(
                    top: BorderSide(
                      color: Color(0xFF49305E),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControl(
                      icon: _microphoneEnabled
                          ? Icons.mic
                          : Icons.mic_off,
                      label: _microphoneEnabled ? 'Mute' : 'Unmute',
                      color: _microphoneEnabled
                          ? const Color(0xFF49305E)
                          : Colors.redAccent,
                      onPressed: _toggleMicrophone,
                    ),
                    _buildControl(
                      icon: Icons.call_end,
                      label: 'End Call',
                      color: Colors.red,
                      onPressed: _endCall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControl({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _ending ? null : onPressed,
          icon: Icon(icon, color: Colors.white, size: 28),
          style: IconButton.styleFrom(
            backgroundColor: color,
            fixedSize: const Size(64, 64),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
