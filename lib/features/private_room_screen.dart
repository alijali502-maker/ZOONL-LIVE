
import 'package:flutter/material.dart';

enum PrivateRoomType {
  audio,
  video,
}

class PrivateRoomScreen extends StatefulWidget {
  final Future<void> Function({
    required PrivateRoomType type,
    required String roomId,
    required String password,
  })? onCreateRoom;

  final Future<void> Function({
    required PrivateRoomType type,
    required String roomId,
    required String password,
  })? onJoinRoom;

  const PrivateRoomScreen({
    super.key,
    this.onCreateRoom,
    this.onJoinRoom,
  });

  @override
  State<PrivateRoomScreen> createState() => _PrivateRoomScreenState();
}

class _PrivateRoomScreenState extends State<PrivateRoomScreen> {
  final _roomIdController = TextEditingController();
  final _passwordController = TextEditingController();

  PrivateRoomType _selectedType = PrivateRoomType.video;

  bool _obscurePassword = true;
  bool _loading = false;

  Future<void> _createRoom() async {
    final callback = widget.onCreateRoom;

    if (callback == null) {
      _showMessage(
        'Room creation backend is not connected yet.',
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await callback(
        type: _selectedType,
        roomId: _roomIdController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      _showMessage('Room creation request completed.');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Unable to create room: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _joinRoom() async {
    final roomId = _roomIdController.text.trim();
    final password = _passwordController.text;

    if (roomId.isEmpty) {
      _showMessage('Please enter Room ID.');
      return;
    }

    if (password.isEmpty) {
      _showMessage('Please enter Room Password.');
      return;
    }

    final callback = widget.onJoinRoom;

    if (callback == null) {
      _showMessage(
        'Room joining backend is not connected yet.',
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await callback(
        type: _selectedType,
        roomId: roomId,
        password: password,
      );

      if (!mounted) return;

      _showMessage('Room join request completed.');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Unable to join room: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _roomTypeCard({
    required PrivateRoomType type,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final selected = _selectedType == type;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _loading
            ? null
            : () {
                setState(() => _selectedType = type);
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF49305E)
                : const Color(0xFF241630),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? const Color(0xFFE5BD70)
                  : const Color(0xFF49305E),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: const Color(0xFFE5BD70),
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
              if (selected) ...[
                const SizedBox(height: 10),
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFFE5BD70),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool password = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: password && _obscurePassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFFE5BD70),
        ),
        suffixIcon: password
            ? IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: Colors.white70,
                ),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF241630),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFF49305E),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFF49305E),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF100B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1225),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'PRIVATE ROOMS',
          style: TextStyle(
            color: Color(0xFFE5BD70),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF6E3B8F),
                    Color(0xFF21152F),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.lock_person,
                    color: Color(0xFFE5BD70),
                    size: 58,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Your Private Space',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Create a private room or join using an invitation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'SELECT ROOM TYPE',
              style: TextStyle(
                color: Color(0xFFE5BD70),
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                _roomTypeCard(
                  type: PrivateRoomType.video,
                  icon: Icons.videocam,
                  title: 'Video Room',
                  description: 'Camera and microphone',
                ),
                const SizedBox(width: 12),
                _roomTypeCard(
                  type: PrivateRoomType.audio,
                  icon: Icons.headphones,
                  title: 'Audio Room',
                  description: 'Voice only',
                ),
              ],
            ),

            const SizedBox(height: 25),

            const Text(
              'ROOM DETAILS',
              style: TextStyle(
                color: Color(0xFFE5BD70),
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            _inputField(
              controller: _roomIdController,
              label: 'Room ID',
              hint: 'Enter your Room ID',
              icon: Icons.meeting_room,
            ),

            const SizedBox(height: 15),

            _inputField(
              controller: _passwordController,
              label: 'Room Password',
              hint: 'Enter room password',
              icon: Icons.lock,
              password: true,
            ),

            const SizedBox(height: 25),

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _createRoom,
                icon: const Icon(Icons.add_home),
                label: const Text('CREATE PRIVATE ROOM'),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _joinRoom,
                icon: const Icon(Icons.login),
                label: const Text('JOIN PRIVATE ROOM'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE5BD70),
                  side: const BorderSide(
                    color: Color(0xFFE5BD70),
                  ),
                ),
              ),
            ),

            if (_loading) ...[
              const SizedBox(height: 20),
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFE5BD70),
                ),
              ),
            ],

            const SizedBox(height: 25),

            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF241630),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.security,
                    color: Color(0xFFE5BD70),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Room access must be verified by the secure server. '
                      'Room IDs, passwords and access tokens must not be '
                      'trusted or generated only on the device.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
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
