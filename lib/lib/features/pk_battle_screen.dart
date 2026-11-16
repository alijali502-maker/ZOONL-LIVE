
import 'dart:async';

import 'package:flutter/material.dart';

enum PkMode { random, group }

class PkBattleScreen extends StatefulWidget {
  final String currentUserName;
  final String currentUserId;

  const PkBattleScreen({
    super.key,
    required this.currentUserName,
    required this.currentUserId,
  });

  @override
  State<PkBattleScreen> createState() => _PkBattleScreenState();
}

class _PkBattleScreenState extends State<PkBattleScreen> {
  PkMode _mode = PkMode.random;

  bool _invitationSent = false;
  bool _invitationAccepted = false;
  bool _battleStarted = false;
  bool _battleEnded = false;

  int _myScore = 0;
  int _opponentScore = 0;
  int _remainingSeconds = 180;

  Timer? _timer;

  final TextEditingController _opponentIdController =
      TextEditingController();

  final List<String> _groupParticipants = [];

  String _opponentName = 'Waiting for opponent';

  String get _timeText {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _sendInvitation() {
    if (_opponentIdController.text.trim().isEmpty) {
      _message('Please enter opponent User ID.');
      return;
    }

    setState(() {
      _invitationSent = true;
      _opponentName = 'Invited User';
    });

    _message('Invitation preview created. Server integration is pending.');
  }

  void _acceptInvitation() {
    setState(() {
      _invitationAccepted = true;
      _opponentName = 'Opponent';
    });
  }

  void _startBattle() {
    if (!_invitationAccepted) {
      _message('Opponent invitation must be accepted first.');
      return;
    }

    setState(() {
      _battleStarted = true;
      _battleEnded = false;
      _remainingSeconds = 180;
      _myScore = 0;
      _opponentScore = 0;
    });

    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds <= 1) {
        timer.cancel();
        _finishBattle();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _finishBattle() {
    _timer?.cancel();

    setState(() {
      _battleStarted = false;
      _battleEnded = true;
      _remainingSeconds = 0;
    });

    _showResult();
  }

  void _showResult() {
    final result = _myScore > _opponentScore
        ? 'You Win!'
        : _myScore < _opponentScore
            ? 'Opponent Wins!'
            : 'Match Draw!';

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF241630),
        title: const Text(
          'PK Result',
          style: TextStyle(color: Color(0xFFE5BD70)),
        ),
        content: Text(
          '$result\n\n$_myScore : $_opponentScore',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _battleEnded = false;
                _invitationSent = false;
                _invitationAccepted = false;
                _opponentIdController.clear();
                _opponentName = 'Waiting for opponent';
              });
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _addMyScore() {
    if (!_battleStarted) return;
    setState(() => _myScore += 1);
  }

  void _addOpponentScore() {
    if (!_battleStarted) return;
    setState(() => _opponentScore += 1);
  }

  void _addGroupParticipant() {
    final id = _opponentIdController.text.trim();

    if (id.isEmpty) {
      _message('Enter participant User ID.');
      return;
    }

    if (_groupParticipants.contains(id)) {
      _message('Participant already added.');
      return;
    }

    setState(() {
      _groupParticipants.add(id);
      _opponentIdController.clear();
    });
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  Widget _scorePanel({
    required String name,
    required int score,
    required bool isMe,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF2A1B39),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isMe
                ? const Color(0xFFE5BD70)
                : const Color(0xFF76518F),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFF49305E),
              child: Icon(
                isMe ? Icons.person : Icons.person_outline,
                color: const Color(0xFFE5BD70),
                size: 34,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '$score',
              style: const TextStyle(
                color: Color(0xFFE5BD70),
                fontSize: 38,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'POINTS',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _opponentIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF100B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1225),
        title: const Text(
          'ZOONL PK BATTLE',
          style: TextStyle(
            color: Color(0xFFE5BD70),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF49305E),
                    Color(0xFF21152F),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text(
                    'PK BATTLE ARENA',
                    style: TextStyle(
                      color: Color(0xFFE5BD70),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Challenge another live host',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 18),
                  SegmentedButton<PkMode>(
                    segments: const [
                      ButtonSegment(
                        value: PkMode.random,
                        label: Text('Random PK'),
                        icon: Icon(Icons.shuffle),
                      ),
                      ButtonSegment(
                        value: PkMode.group,
                        label: Text('Group PK'),
                        icon: Icon(Icons.groups),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (selection) {
                      setState(() => _mode = selection.first);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            if (!_battleStarted && !_battleEnded) ...[
              TextField(
                controller: _opponentIdController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: _mode == PkMode.random
                      ? 'Opponent User ID'
                      : 'Group Participant User ID',
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(
                    Icons.person_search,
                    color: Color(0xFFE5BD70),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF241630),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_mode == PkMode.random)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sendInvitation,
                    icon: const Icon(Icons.send),
                    label: const Text('Send PK Invitation'),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addGroupParticipant,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Group Participant'),
                  ),
                ),

              if (_mode == PkMode.group &&
                  _groupParticipants.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Group Participants',
                  style: TextStyle(color: Color(0xFFE5BD70)),
                ),
                ..._groupParticipants.map(
                  (id) => ListTile(
                    leading: const Icon(
                      Icons.person,
                      color: Colors.white70,
                    ),
                    title: Text(
                      id,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.redAccent,
                      ),
                      onPressed: () {
                        setState(() => _groupParticipants.remove(id));
                      },
                    ),
                  ),
                ),
              ],

              if (_invitationSent) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF241630),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.mark_email_read,
                        color: Color(0xFFE5BD70),
                        size: 36,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Invitation Sent',
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      if (!_invitationAccepted)
                        ElevatedButton(
                          onPressed: _acceptInvitation,
                          child: const Text('Accept Demo Invitation'),
                        ),
                      if (_invitationAccepted)
                        const Text(
                          'Opponent Accepted',
                          style: TextStyle(color: Colors.greenAccent),
                        ),
                    ],
                  ),
                ),
              ],
            ],

            if (_battleStarted || _battleEnded) ...[
              const SizedBox(height: 20),
              Center(
                child: Text(
                  _timeText,
                  style: const TextStyle(
                    color: Color(0xFFE5BD70),
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _scorePanel(
                    name: widget.currentUserName,
                    score: _myScore,
                    isMe: true,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _scorePanel(
                    name: _opponentName,
                    score: _opponentScore,
                    isMe: false,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_battleStarted)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _addMyScore,
                      child: const Text('+ My Score'),
                    ),
                    ElevatedButton(
                      onPressed: _addOpponentScore,
                      child: const Text('+ Opponent'),
                    ),
                  ],
                ),
              const SizedBox(height: 18),
              if (_battleStarted)
                OutlinedButton(
                  onPressed: _finishBattle,
                  child: const Text('End PK Battle'),
                ),
            ],

            if (_invitationAccepted && !_battleStarted && !_battleEnded) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startBattle,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start PK Battle'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
