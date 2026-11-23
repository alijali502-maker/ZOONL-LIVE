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
  List<CameraDescription> _cameras = <CameraDescription>[];
  VideoPlayerController? _preview;
  XFile? _recordedFile;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  bool _cameraLoading = true;
  bool _recording = false;
  bool _uploading = false;
  bool _filterLoading = false;
  String _filter = 'Natural';
  double _filterStrength = 0.65;
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
              red = (red * 1.07 + 0.015).clamp(0.0, 1.0).toDouble();
              blue = (blue * 0.91).clamp(0.0, 1.0).toDouble();
              break;
            case 'Cool':
              red = (red * 0.92).clamp(0.0, 1.0).toDouble();
              blue = (blue * 1.08 + 0.015).clamp(0.0, 1.0).toDouble();
              break;
            case 'Rose':
              red = (red * 1.06 + 0.012).clamp(0.0, 1.0).toDouble();
              blue = (blue * 1.025 + 0.006).clamp(0.0, 1.0).toDouble();
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
    final amount = _filterStrength.clamp(0.0, 1.0);
    if (_filter == 'Mono') {
      const r = 0.2126, g = 0.7152, b = 0.0722;
      return ColorFilter.matrix(<double>[
        1 - amount * (1 - r), amount * g, amount * b, 0, 0,
        amount * r, 1 - amount * (1 - g), amount * b, 0, 0,
        amount * r, amount * g, 1 - amount * (1 - b), 0, 0,
        0, 0, 0, 1, 0,
      ]);
    }
    final tint = switch (_filter) {
      'Warm' => const Color(0xFFFF9A50),
      'Cool' => const Color(0xFF73B9FF),
      'Rose' => const Color(0xFFFF78B7),
      _ => Colors.transparent,
    };
    if (tint == Colors.transparent || amount == 0) {
      return const ColorFilter.mode(Colors.transparent, BlendMode.dst);
    }
    return ColorFilter.mode(
      tint.withOpacity(0.42 * amount),
      BlendMode.softLight,
    );
  }

  Widget _filteredPreview(Widget child) {
    final lut = _activeLut;
    final withLut = lut == null
        ? child
        : LutFilter(lut: lut, intensity: _filterStrength, child: child);
    return ColorFiltered(colorFilter: _previewFilter, child: withLut);
  }

  Widget _cameraSurface(CameraController camera, Size viewport) {
    final previewSize = camera.value.previewSize;
    if (previewSize == null) {
      return Center(child: AspectRatio(
        aspectRatio: camera.value.aspectRatio,
        child: _filteredPreview(CameraPreview(camera)),
      ));
    }
    final portraitWidth = previewSize.height;
    final portraitHeight = previewSize.width;
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: portraitWidth,
            height: portraitHeight,
            child: _filteredPreview(CameraPreview(camera)),
          ),
        ),
      ),
    );
  }

  Widget _videoSurface(VideoPlayerController preview) {
    final videoSize = preview.value.size;
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: videoSize.width,
            height: videoSize.height,
            child: _filteredPreview(VideoPlayer(preview)),
          ),
        ),
      ),
    );
  }

  Future<void> _initializeCamera({CameraLensDirection? preferredDirection}) async {
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
      _cameras = cameras;
      final direction = preferredDirection ?? CameraLensDirection.front;
      final matching = cameras.where((c) => c.lensDirection == direction);
      final selected = matching.isNotEmpty ? matching.first : cameras.first;
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

  Future<void> _flipCamera() async {
    if (_recording || _uploading || _cameraLoading || _cameras.length < 2) return;
    final current = _camera?.description.lensDirection ?? CameraLensDirection.front;
    final next = current == CameraLensDirection.front ? CameraLensDirection.back : CameraLensDirection.front;
    final old = _camera;
    _camera = null;
    await old?.dispose();
    if (mounted) setState(() { _cameraLoading = true; });
    await _initializeCamera(preferredDirection: next);
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
          edit: EditSpec(lut: lutPath, lutIntensity: _filterStrength, maxDimension: 1080),
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
        fileOptions: FileOptions(contentType: 'video/mp4', upsert: false),
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
    final mediaReady = (preview != null && preview.value.isInitialized) || (camera != null && camera.value.isInitialized);
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF05070D),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: const Text('SHORT VIDEO STUDIO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: .8)),
        actions: [
          IconButton.filledTonal(tooltip: 'Switch camera',
            onPressed: _recording || _uploading || _cameraLoading || _cameras.length < 2 ? null : _flipCamera,
            icon: const Icon(Icons.flip_camera_android)),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(fit: StackFit.expand, children: [
        if (_cameraLoading)
          const Center(child: CircularProgressIndicator())
        else if (preview != null && preview.value.isInitialized)
          _videoSurface(preview)
        else if (camera != null && camera.value.isInitialized)
          _cameraSurface(camera, size)
        else
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.no_photography, color: Color(0xFFB9AEFF), size: 48),
            Text(_error ?? 'Camera unavailable', style: const TextStyle(color: Colors.white70)),
            TextButton(onPressed: _initializeCamera, child: const Text('Retry camera')),
          ])),
        const Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter,end: Alignment.bottomCenter,
            colors:[Color(0x88000000),Colors.transparent,Color(0xF0000000)],stops:[0,.42,1]))))),
        if (_recording) Positioned(top: MediaQuery.of(context).padding.top + 62,left: 16,
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 12,vertical: 7),
            decoration: BoxDecoration(color: Colors.redAccent,borderRadius: BorderRadius.circular(20)),
            child: Text('● REC  $_recordingSeconds s',style: const TextStyle(color: Colors.white,fontWeight: FontWeight.w900,fontSize: 11)))),
        Positioned(left: 12,right: 12,bottom: 10,
          child: ConstrainedBox(constraints: BoxConstraints(maxHeight: size.height * .48),
            child: ClipRRect(borderRadius: BorderRadius.circular(22),
              child: Container(color: const Color(0xE6101420),padding: const EdgeInsets.fromLTRB(13,12,13,12),
                child: SingleChildScrollView(child: Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Row(children:[
                    const Text('LOOKS & CAMERA',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:11,letterSpacing:.8)),
                    const Spacer(),
                    Text(_filterLoading?'Preparing LUT…':_filter,style:const TextStyle(color:Color(0xFFE6C47A),fontSize:10,fontWeight:FontWeight.w800)),
                  ]),
                  const SizedBox(height:8),
                  SizedBox(
                    height: 54,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 9),
                      itemBuilder: (context, index) {
                        final filter = _filters[index];
                        final selected = _filter == filter;
                        final swatch = switch (filter) {
                          'Warm' => const Color(0xFFFFA45C),
                          'Cool' => const Color(0xFF70BFFF),
                          'Rose' => const Color(0xFFFF78B7),
                          'Mono' => const Color(0xFFB9C0CC),
                          _ => const Color(0xFFE6C47A),
                        };
                        return InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: _recording || _uploading ? null : () {
                            setState(() => _filter = filter);
                            _loadFilterLut();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 68,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xFF3A2B43) : const Color(0xFF202638),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: selected ? const Color(0xFFE6C47A) : Colors.white12,
                                width: selected ? 1.6 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 23, height: 23,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(colors: [swatch, swatch.withOpacity(.28)]),
                                  ),
                                  child: selected ? const Icon(Icons.check, size: 14, color: Colors.black) : null,
                                ),
                                const SizedBox(height: 4),
                                Text(filter, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: selected ? const Color(0xFFE6C47A) : Colors.white70,
                                    fontSize: 9, fontWeight: FontWeight.w800,
                                  )),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Row(children:[
                    const Text('Intensity',style:TextStyle(color:Colors.white70,fontSize:10)),
                    Expanded(child:Slider(value:_filterStrength,min:0,max:1,onChanged:_recording||_uploading?null:(v)=>setState(()=>_filterStrength=v))),
                    Text('\${(_filterStrength*100).round()}%',style:const TextStyle(color:Colors.white,fontSize:10)),
                  ]),
                  TextField(controller:_caption,maxLength:180,style:const TextStyle(color:Colors.white,fontSize:12),
                    decoration:InputDecoration(labelText:'Caption',labelStyle:const TextStyle(color:Colors.white70,fontSize:11),
                      counterText:'',isDense:true,filled:true,fillColor:const Color(0xFF202638),
                      border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide.none))),
                  Text('Duration: $_recordingSeconds / 60 sec',style:const TextStyle(color:Color(0xFFB9AEFF),fontSize:10)),
                  const SizedBox(height:7),
                  if (_recording)
                    SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:_stopRecording,
                      icon:const Icon(Icons.stop_circle),label:const Text('STOP RECORDING'),
                      style:FilledButton.styleFrom(backgroundColor:Colors.redAccent)))
                  else if (preview == null)
                    SizedBox(width:double.infinity,child:FilledButton.icon(
                      onPressed:_cameraLoading||_uploading||_filterLoading||!mediaReady?null:_startRecording,
                      icon:const Icon(Icons.fiber_manual_record),label:const Text('RECORD SHORT')))
                  else ...[
                    SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:_uploading||_filterLoading?null:_uploadVideo,
                      icon:const Icon(Icons.cloud_upload),label:Text(_uploading?'PUBLISHING…':'PUBLISH SHORT'))),
                    SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:_uploading?null:_retake,
                      icon:const Icon(Icons.refresh),label:const Text('RETAKE'))),
                  ],
                ])),
              )))),
      ]),
    );
  }
}
