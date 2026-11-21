import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:filmkit/filmkit.dart';
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
  bool _filterLoading = false;
  String _filter = 'Natural';
  CubeLut? _activeLut;
  String? _activeLutPath;
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
    _loadFilterLut();
    _initializeCamera();
  }

  String _filterLutText(String filter) {
    const size = 17;
    final out = StringBuffer()
      ..writeln('TITLE "$filter"')
      ..writeln('LUT_3D_SIZE $size')
      ..writeln('DOMAIN_MIN 0.0 0.0 0.0')
      ..writeln('DOMAIN_MAX 1.0 1.0 1.0');
    for (var b = 0; b < size; b++) {
      for (var g = 0; g < size; g++) {
        for (var r = 0; r < size; r++) {
          var red = r / (size - 1);
          var green = g / (size - 1);
          var blue = b / (size - 1);
          switch (filter) {
            case 'Warm':
              red = (red * 1.07 + 0.015).clamp(0.0, 1.0);
              blue = (blue * 0.91).clamp(0.0, 1.0);
              break;
            case 'Cool':
              red = (red * 0.92).clamp(0.0, 1.0);
              blue = (blue * 1.08 + 0.015).clamp(0.0, 1.0);
              break;
            case 'Rose':
              red = (red * 1.06 + 0.012).clamp(0.0, 1.0);
              blue = (blue * 1.025 + 0.006).clamp(0.0, 1.0);
              break;
            case 'Mono':
              final luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue;
              red = luminance;
              green = luminance;
              blue = luminance;
              break;
          }
          out.writeln('${red.toStringAsFixed(6)} ${green.toStringAsFixed(6)} ${blue.toStringAsFixed(6)}');
        }
      }
    }
    return out.toString();
  }

  Future<void> _loadFilterLut() async {
    final selectedFilter = _filter;
    if (selectedFilter == 'Natural') {
      if (mounted) setState(() {
        _activeLut = null;
        _activeLutPath = null;
        _filterLoading = false;
      });
      return;
    }
    if (mounted) setState(() => _filterLoading = true);
    try {
      final path = '${Directory.systemTemp.path}/zoonl_${selectedFilter.toLowerCase()}_17.cube';
      final lutFile = File(path);
      if (!await lutFile.exists()) {
        await lutFile.writeAsString(_filterLutText(selectedFilter), flush: true);
      }
      final lut = await CubeLut.fromFile(path);
      if (!mounted || _filter != selectedFilter) return;
      setState(() {
        _activeLut = lut;
        _activeLutPath = path;
        _filterLoading = false;
      });
    } catch (error) {
      if (mounted && _filter == selectedFilter) {
        setState(() => _filterLoading = false);
        _notice('Filter could not load: $error');
      }
    }
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
    String? processedPath;
    try {
      File localFile = File(file.path);
      final originalSize = await localFile.length();
      if (originalSize > 100 * 1024 * 1024) {
        throw StateError('Video file is larger than 100 MB.');
      }

      if (_filter != 'Natural') {
        final lutPath = _activeLutPath;
        if (lutPath == null || _activeLut == null) {
          throw StateError('Selected filter is not ready. Please select it again.');
        }
        processedPath = '${Directory.systemTemp.path}/zoonl_filtered_${DateTime.now().microsecondsSinceEpoch}.mp4';
        final export = Filmkit.exportVideo(
          input: localFile.path,
          output: processedPath,
          edit: EditSpec(lut: lutPath, lutIntensity: 1.0, maxDimension: 1080),
        );
        await export.result;
        localFile = File(processedPath);
        if (!await localFile.exists() || await localFile.length() == 0) {
          throw StateError('Filtered video export did not create a valid MP4.');
        }
      }

      final size = await localFile.length();
      if (size > 100 * 1024 * 1024) {
        throw StateError('Processed video is larger than 100 MB.');
      }
      uploadedPath = '$userId/${DateTime.now().microsecondsSinceEpoch}.mp4';
      await _db.storage.from('zoonl-shorts').upload(
        uploadedPath,
        localFile,
        fileOptions: const FileOptions(contentType: 'video/mp4', upsert: false),
      );
      final publicUrl = _db.storage.from('zoonl-shorts').getPublicUrl(uploadedPath);
      await _db.from('short_videos').insert({
        'user_id': userId,
        'storage_path': uploadedPath,
        'video_url': publicUrl,
        'caption': _caption.text.trim(),
        'filter_name': _filter,
        'is_filter_baked': true,
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
      if (processedPath != null) {
        try { await File(processedPath).delete(); } catch (_) {}
      }
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
      backgroundColor: const Color(0xFF070B17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1426),
        title: const Text('SHORT VIDEO STUDIO',
            style: TextStyle(color: Color(0xFFB9AEFF), fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Container(
              height: 430,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF141E35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF56638F)),
              ),
              child: _cameraLoading
                  ? const Center(child: CircularProgressIndicator())
                  : preview != null && preview.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: preview.value.aspectRatio,
                          child: _activeLut == null
                              ? VideoPlayer(preview)
                              : LutFilter(lut: _activeLut!, intensity: 1, child: VideoPlayer(preview)),
                        )
                      : camera != null && camera.value.isInitialized
                          ? (_activeLut == null
                              ? CameraPreview(camera)
                              : LutFilter(lut: _activeLut!, intensity: 1, child: CameraPreview(camera)))
                          : Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.no_photography, color: Color(0xFFB9AEFF), size: 48),
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
                onSelected: _recording || _uploading ? null : (_) { setState(() => _filter = filter); _loadFilterLut(); },
              )).toList(),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 7),
              child: Text(
                'The same selected colour filter is previewed and encoded into the MP4 before it is published. Audio is preserved.',
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
              style: const TextStyle(color: Color(0xFFB9AEFF)),
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
                onPressed: _cameraLoading || _uploading || _filterLoading ? null : _startRecording,
                icon: const Icon(Icons.fiber_manual_record),
                label: const Text('Record Short'),
              )
            else ...[
              FilledButton.icon(
                onPressed: _uploading || _filterLoading ? null : _uploadVideo,
                icon: const Icon(Icons.cloud_upload),
                label: Text(_filterLoading ? 'Loading filter...' : _uploading ? 'Uploading...' : 'Publish Short'),
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
