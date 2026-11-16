
import 'package:flutter/material.dart';

class LiveScreen extends StatefulWidget {
  final String userName;
  final String userId;

  const LiveScreen({
    super.key,
    required this.userName,
    required this.userId,
  });

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  bool _isLive = false;
  bool _isHost = true;
  bool _microphoneEnabled = true;
  bool _cameraEnabled = true;
  bool _chatEnabled = true;

  final TextEditingController _titleController =
      TextEditingController();

  final TextEditingController _messageController =
      TextEditingController();

  final List<Map<String, String>> _messages = [];

  void _startLive() {
    if (_titleController.text.trim().isEmpty) {
      _showMessage('Please enter a live room title.');
      return;
    }

    setState(() {
      _isLive = true;
      _isHost = true;
    });

    _showMessage('Live preview started. Streaming server integration is pending.');
  }

  void _endLive() {
    setState(() {
      _isLive = false;
    });

    _showMessage('Live session preview ended.');
  }

  void _sendMessage() {
    final message = _messageController.text.trim();

    if (message.isEmpty) return;

    setState(() {
      _messages.add({
        'name': widget.userName,
        'message': message,
      });

      _messageController.clear();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _control({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = const Color(0xFF39234D),
  }) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white),
          style: IconButton.styleFrom(
            backgroundColor: color,
            fixedSize: const Size(52, 52),
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
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF100B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1225),
        title: const Text(
          'ZOONL LIVE ROOM',
          style: TextStyle(
            color: Color(0xFFE5BD70),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: !_isLive
            ? _buildStartScreen()
            : _buildLiveRoom(),
      ),
    );
  }

  Widget _buildStartScreen() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          height: 190,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF6E3B8F),
                Color(0xFF21152F),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Center(
            child: Icon(
              Icons.live_tv,
              size: 85,
              color: Color(0xFFE5BD70),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Start Your Live Room',
          style: TextStyle(
            color: Color(0xFFE5BD70),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _titleController,
          style: const TextStyle(color: Colors.white),
          maxLength: 60,
          decoration: InputDecoration(
            labelText: 'Live Room Title',
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: const Color(0xFF241630),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF241630),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.person,
                color: Color(0xFFE5BD70),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${widget.userName}  •  ID ${widget.userId}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _startLive,
            icon: const Icon(Icons.play_circle),
            label: const Text('GO LIVE'),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveRoom() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                color: const Color(0xFF21152F),
                child: const Center(
                  child: Icon(
                    Icons.person,
                    size: 110,
                    color: Color(0xFFE5BD70),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: Colors.white,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.visibility,
                        color: Colors.white,
                        size: 17,
                      ),
                      SizedBox(width: 6),
                      Text(
                        '0',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                bottom: 14,
                child: Text(
                  widget.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_chatEnabled)
          Container(
            height: 145,
            padding: const EdgeInsets.all(10),
            color: const Color(0xFF1B1225),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final item = _messages[index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          '${item['name']}: ${item['message']}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Write a message...',
                          hintStyle: TextStyle(color: Colors.white54),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(
                        Icons.send,
                        color: Color(0xFFE5BD70),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 14,
          ),
          color: const Color(0xFF1B1225),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _control(
                icon: _microphoneEnabled
                    ? Icons.mic
                    : Icons.mic_off,
                label: 'Microphone',
                onTap: () {
                  setState(() {
                    _microphoneEnabled = !_microphoneEnabled;
                  });
                },
              ),
              _control(
                icon: _cameraEnabled
                    ? Icons.videocam
                    : Icons.videocam_off,
                label: 'Camera',
                onTap: () {
                  setState(() {
                    _cameraEnabled = !_cameraEnabled;
                  });
                },
              ),
              _control(
                icon: Icons.sports_kabaddi,
                label: 'PK Battle',
                onTap: () {
                  _showMessage(
                    'Connect the PK Battle screen in the integration step.',
                  );
                },
              ),
              _control(
                icon: Icons.chat,
                label: 'Chat',
                onTap: () {
                  setState(() {
                    _chatEnabled = !_chatEnabled;
                  });
                },
              ),
              _control(
                icon: Icons.call_end,
                label: 'End Live',
                color: Colors.red,
                onTap: _endLive,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
