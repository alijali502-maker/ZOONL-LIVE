import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

class ShortVideoFeedScreen extends StatefulWidget {
  final bool onlyMine;
  const ShortVideoFeedScreen({super.key, this.onlyMine = false});

  @override
  State<ShortVideoFeedScreen> createState() => _ShortVideoFeedScreenState();
}

class _ShortVideoFeedScreenState extends State<ShortVideoFeedScreen> {
  final SupabaseClient _db = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _videos = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final select = _db.from('short_videos').select(
        'id,user_id,video_url,caption,filter_name,is_filter_baked,duration_seconds,likes_count,created_at',
      );
      final rows = widget.onlyMine
          ? await select
              .eq('user_id', _db.auth.currentUser?.id ?? '')
              .order('created_at', ascending: false)
              .limit(60)
          : await select
              .eq('is_public', true)
              .order('created_at', ascending: false)
              .limit(60);
      if (widget.onlyMine && _db.auth.currentUser == null) {
        throw StateError('Login required.');
      }
      final videos = (rows as List).map((e) => Map<String,dynamic>.from(e)).toList();
      final ids = videos.map((e) => e['user_id'].toString()).toSet().toList();
      if (ids.isNotEmpty) {
        final profiles = await _db.from('user_public_profiles')
            .select('user_id,zoonl_id').inFilter('user_id', ids);
        final idMap = <String,String>{
          for (final p in profiles as List) p['user_id'].toString(): p['zoonl_id'].toString(),
        };
        for (final video in videos) {
          video['zoonl_id'] = idMap[video['user_id'].toString()] ?? 'Member';
        }
      }
      if (mounted) setState(() { _videos = videos; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = error.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1426),
        title: Text(widget.onlyMine ? 'MY SHORTS' : 'SHORT VIDEO FEED',
          style: const TextStyle(color: Color(0xFFB9AEFF), fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(_error!, style: const TextStyle(color: const Color(0xFF9B8CFF))),
                ))
              : _videos.isEmpty
                  ? const Center(child: Text('No short videos yet.', style: TextStyle(color: Colors.white70)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _videos.length,
                        itemBuilder: (context,index) {
                          final video = _videos[index];
                          return Card(
                            color: const Color(0xFF141E35),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFF29395D),
                                child: Icon(Icons.play_arrow, color: Color(0xFFB9AEFF)),
                              ),
                              title: Text(
                                (video['caption'] ?? 'ZOONL Short').toString().isEmpty
                                    ? 'ZOONL Short' : (video['caption'] ?? '').toString(),
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                'ID ${video['zoonl_id']} • ${video['duration_seconds']} sec • ${video['likes_count']} likes',
                                style: const TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                              trailing: const Icon(Icons.chevron_right, color: Color(0xFFB9AEFF)),
                              onTap: () async {
                                await Navigator.of(context).push(MaterialPageRoute<void>(
                                  builder: (_) => ShortVideoPlayerScreen(video: video),
                                ));
                                _load();
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class ShortVideoPlayerScreen extends StatefulWidget {
  final Map<String, dynamic> video;
  const ShortVideoPlayerScreen({super.key, required this.video});

  @override
  State<ShortVideoPlayerScreen> createState() => _ShortVideoPlayerScreenState();
}

class _ShortVideoPlayerScreenState extends State<ShortVideoPlayerScreen> {
  final SupabaseClient _db = Supabase.instance.client;
  VideoPlayerController? _controller;
  bool _liked = false;
  bool _busy = false;
  String? _error;
  int _likes = 0;

  @override
  void initState() {
    super.initState();
    _likes = (widget.video['likes_count'] as num?)?.toInt() ?? 0;
    _initialize();
    _loadLiked();
  }

  Future<void> _initialize() async {
    try {
      final url = Uri.parse(widget.video['video_url'].toString());
      final controller = VideoPlayerController.networkUrl(url);
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) { await controller.dispose(); return; }
      setState(() => _controller = controller);
      await controller.play();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _loadLiked() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final row = await _db.from('short_video_likes')
          .select('video_id')
          .eq('video_id', widget.video['id'])
          .eq('user_id', uid)
          .maybeSingle();
      if (mounted) setState(() => _liked = row != null);
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await _db.rpc(
        'toggle_short_video_like',
        params: {'p_video_id': widget.video['id']},
      );
      if (mounted) {
        setState(() {
          _liked = result['liked'] == true;
          _likes = (result['likes_count'] as num?)?.toInt() ?? _likes;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Like update failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) controller.dispose();
    super.dispose();
  }

  ColorFilter get _legacyFilter {
    switch (widget.video['filter_name']?.toString()) {
      case 'Warm':
        return const ColorFilter.mode(Color(0x55FF9A50), BlendMode.softLight);
      case 'Cool':
        return const ColorFilter.mode(Color(0x5573B9FF), BlendMode.softLight);
      case 'Rose':
        return const ColorFilter.mode(Color(0x55FF78B7), BlendMode.softLight);
      case 'Mono':
        return const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      default:
        return const ColorFilter.mode(Colors.transparent, BlendMode.dst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final filterAlreadyBaked = widget.video['is_filter_baked'] == true;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1426),
        title: const Text('ZOONL SHORT', style: TextStyle(color: Color(0xFFB9AEFF))),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _error != null
                  ? Text(_error!, style: const TextStyle(color: Colors.white70))
                  : controller == null || !controller.value.isInitialized
                      ? const CircularProgressIndicator()
                      : AspectRatio(
                          aspectRatio: controller.value.aspectRatio,
                          child: filterAlreadyBaked
                              ? VideoPlayer(controller)
                              : ColorFiltered(
                                  colorFilter: _legacyFilter,
                                  child: VideoPlayer(controller),
                                ),
                        ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF0D1426),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((widget.video['caption'] ?? '').toString(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('ID ${widget.video['zoonl_id']}',
                        style: const TextStyle(color: Colors.white60)),
                    const Spacer(),
                    IconButton(
                      onPressed: _busy ? null : _toggleLike,
                      icon: Icon(_liked ? Icons.favorite : Icons.favorite_border,
                          color: _liked ? Colors.pinkAccent : Colors.white),
                    ),
                    Text('$_likes', style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
