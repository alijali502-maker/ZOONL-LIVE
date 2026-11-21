import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Compact metallic level insignia shown directly beneath the profile avatar.
/// The level is always read from the trusted server RPC, never from a client ID.
class ZoonlMiniLevelBadge extends StatefulWidget {
  final VoidCallback? onTap;
  const ZoonlMiniLevelBadge({super.key, this.onTap});

  @override
  State<ZoonlMiniLevelBadge> createState() => _ZoonlMiniLevelBadgeState();
}

class _ZoonlMiniLevelBadgeState extends State<ZoonlMiniLevelBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();
  late Future<int> _levelFuture;

  @override
  void initState() {
    super.initState();
    _levelFuture = _loadLevel();
  }

  Future<int> _loadLevel() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return 1;
    final result = await client.rpc('zoonl_my_level');
    return (result as num?)?.toInt().clamp(1, 100) ?? 1;
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  List<Color> _metal(int level) {
    if (level >= 100) {
      return const [Color(0xFFFFF5C6), Color(0xFFE5B84D), Color(0xFF75420D)];
    }
    if (level >= 81) {
      return const [Color(0xFFE9DFFF), Color(0xFF9C7BDE), Color(0xFF39245F)];
    }
    if (level >= 51) {
      return const [Color(0xFFFFE7A0), Color(0xFFB98226), Color(0xFF59350B)];
    }
    if (level >= 21) {
      return const [Color(0xFFD8F5FF), Color(0xFF6C9FC0), Color(0xFF1C3C58)];
    }
    return const [Color(0xFFE4E9F2), Color(0xFF7C8DA5), Color(0xFF283447)];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _levelFuture,
      builder: (context, snapshot) {
        final level = snapshot.data ?? 1;
        final colors = _metal(level);
        return GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _shine,
            builder: (context, child) => Container(
              height: 24,
              constraints: const BoxConstraints(minWidth: 72, maxWidth: 92),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0xFFFFF4C5), width: .8),
                boxShadow: [
                  BoxShadow(color: colors.first.withOpacity(.48), blurRadius: 9, spreadRadius: .3),
                  const BoxShadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Align(
                        alignment: Alignment(-1 + _shine.value * 2, 0),
                        child: Container(
                          width: 15,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Color(0xCCFFFFFF), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield, size: 13, color: Color(0xFF241707)),
                      const SizedBox(width: 4),
                      Text(
                        level >= 100 ? 'OWNER 100' : 'LEVEL ${level.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Color(0xFF241707),
                          fontSize: 8,
                          letterSpacing: .45,
                          fontWeight: FontWeight.w900,
                          shadows: [Shadow(color: Colors.white70, blurRadius: 2)],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
