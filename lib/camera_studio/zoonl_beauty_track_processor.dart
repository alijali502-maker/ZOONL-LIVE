import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_client/livekit_client.dart';

/// Native frame processor used by the LiveKit camera track.
/// Android/iOS runners attach their processor directly to flutter_webrtc's
/// local camera source, so processed frames are what the publisher sends.
class ZoonlBeautyTrackProcessor extends TrackProcessor<VideoProcessorOptions> {
  ZoonlBeautyTrackProcessor({
    required this.look,
    required this.intensity,
    required this.smoothing,
    required this.glow,
    required this.brightness,
    required this.warmth,
  });

  static const MethodChannel _channel = MethodChannel('zoonl.live/beauty');

  String look;
  double intensity;
  double smoothing;
  double glow;
  double brightness;
  double warmth;

  String? _trackId;

  Map<String, Object> get _settings => <String, Object>{
        'look': look,
        'intensity': intensity.clamp(0.0, 1.0),
        'smoothing': smoothing.clamp(0.0, 1.0),
        'glow': glow.clamp(0.0, 1.0),
        'brightness': brightness.clamp(-1.0, 1.0),
        'warmth': warmth.clamp(-1.0, 1.0),
      };

  @override
  String get name => 'zoonl_native_beauty';

  @override
  MediaStreamTrack? get processedTrack => null;

  @override
  Future<void> init(VideoProcessorOptions options) async {
    _trackId = options.track.id;
    await _channel.invokeMethod<void>('addBeauty', <String, Object>{
      'trackId': _trackId!,
      ..._settings,
    });
  }


  Future<void> update({
    required String look,
    required double intensity,
    required double smoothing,
    required double glow,
    required double brightness,
    required double warmth,
  }) async {
    this.look = look;
    this.intensity = intensity;
    this.smoothing = smoothing;
    this.glow = glow;
    this.brightness = brightness;
    this.warmth = warmth;
    final id = _trackId;
    if (id == null) return;
    await _channel.invokeMethod<void>('addBeauty', <String, Object>{
      'trackId': id,
      ..._settings,
    });
  }

  @override
  Future<void> restart(VideoProcessorOptions options) async {
    final previous = _trackId;
    if (previous != null && previous != options.track.id) {
      await _channel.invokeMethod<void>('removeBeauty', <String, Object>{
        'trackId': previous,
      });
    }
    _trackId = options.track.id;
    await _channel.invokeMethod<void>('addBeauty', <String, Object>{
      'trackId': _trackId!,
      ..._settings,
    });
  }

  @override
  Future<void> onPublish(Room room) async {}

  @override
  Future<void> onUnpublish() async {}

  @override
  Future<void> destroy() async {
    final id = _trackId;
    _trackId = null;
    if (id != null) {
      await _channel.invokeMethod<void>('removeBeauty', <String, Object>{
        'trackId': id,
      });
    }
  }
}
