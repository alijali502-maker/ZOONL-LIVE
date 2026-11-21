import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

class ShortVideoStudioScreen extends StatefulWidget {
  const ShortVideoStudioScreen({super.key});

  @override
  State<ShortVideoStudioScreen> createState() => _ShortVideoStudioScreenState();
}

class _ShortVideoStudioScreenState extends State<ShortVideoStudioScreen> {
  final SupabaseClient _db = Supabase.instance.client;
  final TextEditingController _caption = TextEditingController();
  CameraController? _camera;
  VideoPlayerController? _preview;
  XFile? _recordedFile;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  bool _cameraLoading = true;
  bool _recording = false;
  bool _uploading = false;
  String _filter = 'Natural';
  String? _error;

  static const List<String> _filters = [
    'Natural',
    'Warm',
    'Cool',
    'Rose',
    'Mono',
  ];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  ColorFilter get _previewFilter {
    switch (_filter) {
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

  Future<void> _initializeCamera() async {
    setState(() {
      _cameraLoading = true;
      _error = null;
    });
    CameraController? next;
    try {
      final cameraPermission = await Permission.camera.request();
      final microphonePermission = await Permission.microphone.request();
      if (!cameraPermission.isGranted || !microphonePermission.isGranted) {
        throw StateError('Camera and microphone permissions are required.');
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera is available.');
      final front = cameras.where((c) => c.lensDirection == CameraLensDirection.front);
      final selected = front.isNotEmpty ? front.first : cameras.first;
      next = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: true,
      );
      await next.initialize();
      if (!mounted) {
        await next.dispose();
        return;
      }
      _camera = next;
      next = null;
    } catch (error) {
      await next?.dispose();
      if (mounted) _error = error.toString();
    } finally {
      if (mounted) setState(() => _cameraLoading = false);
    }
  }

  Future<void> _startRecording() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _recording || _uploading) return;
    try {
      await _preview?.pause();
      await _preview?.dispose();
      _preview = null;
      _recordedFile = null;
      _recordingSeconds = 0;
      await camera.startVideoRecording();
      setState(() => _recording = true);
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _recordingSeconds++);
        if (_recordingSeconds >= 60) _stopRecording();
      });
    } catch (error) {
      _notice('Recording could not start: $error');
    }
  }

  Future<void> _stopRecording() async {
    final camera = _camera;
    if (camera == null || !_recording) return;
    _recordingTimer?.cancel();
    try {
      final file = await camera.stopVideoRecording();
      if (!mounted) return;
      _recordedFile = file;
      setState(() => _recording = false);
      final preview = VideoPlayerController.file(File(file.path));
      await preview.initialize();
      await preview.setLooping(true);
      if (!mounted) {
        await preview.dispose();
        return;
      }
      setState(() => _preview = preview);
      await preview.play();
    } catch (error) {
      if (mounted) setState(() => _recording = false);
      _notice('Recording could not be saved: $error');
    }
  }

  Future<void> _retake() async {
    await _preview?.pause();
    await _preview?.dispose();
    if (!mounted) return;
    setState(() {
      _preview = null;
      _recordedFile = null;
      _recordingSeconds = 0;
    });
  }

  Future<void> _uploadVideo() async {
    final file = _recordedFile;
    final userId = _db.auth.currentUser?.id;
    if (file == null || userId == null || _uploading) return;
    if (_recordingSeconds < 1 || _recordingSeconds > 60) {
      _notice('Video must be between 1 and 60 seconds.');
      return;
    }
    setState(() => _uploading = true);
    String? uploadedPath;
    try {
      final localFile = File(file.path);
      final size = await localFile.length();
      if (size > 100 * 1024 * 1024) {
        throw StateError('Video file is larger than 100 MB.');
      }
      final extension = file.path.toLowerCase().endsWith('.mov') ? 'mov' : 'mp4';
      final mime = extension == 'mov' ? 'video/quicktime' : 'video/mp4';
      uploadedPath = '$userId/${DateTime.now().microsecondsSinceEpoch}.$extension';

      await _db.storage.from('zoonl-shorts').upload(
        uploadedPath,
        localFile,
        fileOptions: FileOptions(contentType: mime, upsert: false),
      );
      final publicUrl = _db.storage.from('zoonl-shorts').getPublicUrl(uploadedPath);
      await _db.from('short_videos').insert({
        'user_id': userId,
        'storage_path': uploadedPath,
        'video_url': publicUrl,
        'caption': _caption.text.trim(),
        'filter_name': _filter,
        'duration_seconds': _recordingSeconds,
        'is_public': true,
      });

      if (!mounted) return;
      _notice('Short video uploaded to the public feed.');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (uploadedPath != null) {
        try { await _db.storage.from('zoonl-shorts').remove([uploadedPath]); } catch (_) {}
      }
      _notice('Upload failed: $error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _notice(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _caption.dispose();
    final camera = _camera;
    if (camera != null) unawaited(camera.dispose());
    final preview = _preview;
    if (preview != null) unawaited(preview.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final preview = _preview;
    return Scaffold(
      backgroundColor: const Color(0xFF100B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1225),
        title: const Text('SHORT VIDEO STUDIO',
            style: TextStyle(color: Color(0xFFE5BD70), fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Container(
              height: 430,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF21152F),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF6C4A82)),
              ),
              child: _cameraLoading
                  ? const Center(child: CircularProgressIndicator())
                  : preview != null && preview.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: preview.value.aspectRatio,
                          child: VideoPlayer(preview),
                        )
                      : camera != null && camera.value.isInitialized
                          ? ColorFiltered(
                              colorFilter: _previewFilter,
                              child: CameraPreview(camera),
                            )
                          : Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.no_photography, color: Color(0xFFE5BD70), size: 48),
                                  Text(_error ?? 'Camera unavailable',
                                      style: const TextStyle(color: Colors.white70)),
                                  TextButton(onPressed: _initializeCamera, child: const Text('Retry')),
                                ],
                              ),
                            ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: _filters.map((filter) => ChoiceChip(
                label: Text(filter),
                selected: _filter == filter,
                onSelected: _recording || _uploading ? null : (_) => setState(() => _filter = filter),
              )).toList(),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 7),
              child: Text(
                'Colour filters currently affect the camera preview only. The uploaded recording remains the original camera video.',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _caption,
              maxLength: 180,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Caption',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
              ),
            ),
            Text(
              'Duration: $_recordingSeconds / 60 sec',
              style: const TextStyle(color: Color(0xFFE5BD70)),
            ),
            const SizedBox(height: 10),
            if (_recording)
              FilledButton.icon(
                onPressed: _stopRecording,
                icon: const Icon(Icons.stop_circle),
                label: const Text('Stop Recording'),
                style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              )
            else if (preview == null)
              FilledButton.icon(
                onPressed: _cameraLoading || _uploading ? null : _startRecording,
                icon: const Icon(Icons.fiber_manual_record),
                label: const Text('Record Short'),
              )
            else ...[
              FilledButton.icon(
                onPressed: _uploading ? null : _uploadVideo,
                icon: const Icon(Icons.cloud_upload),
                label: Text(_uploading ? 'Uploading...' : 'Publish Short'),
              ),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _retake,
                icon: const Icon(Icons.refresh),
                label: const Text('Retake'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
