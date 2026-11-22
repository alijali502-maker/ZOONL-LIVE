/// Shared settings for the ZOONL LIVE camera effects.
///
/// This file contains effect intent/configuration only. It does not claim to
/// process camera frames. The same serializable settings can be consumed by
/// the Android/iOS preview, LiveKit publisher and short-video export adapters.
enum ZoonlCameraMode { beauty, faceStudio }

enum ZoonlBeautyLook {
  natural,
  softGlow,
  warmLight,
  coolLight,
  studio,
}

enum ZoonlFaceStudioMode {
  off,
  avatar,
  mask,
  arEffects,
}

class ZoonlBeautySettings {
  const ZoonlBeautySettings({
    this.look = ZoonlBeautyLook.natural,
    this.intensity = 0.35,
    this.smoothing = 0.15,
    this.glow = 0.15,
    this.brightness = 0,
    this.warmth = 0,
    this.eyeLens = 'none',
    this.makeup = 'none',
  });

  final ZoonlBeautyLook look;
  final double intensity;
  final double smoothing;
  final double glow;
  final double brightness;
  final double warmth;
  final String eyeLens;
  final String makeup;

  ZoonlBeautySettings copyWith({
    ZoonlBeautyLook? look,
    double? intensity,
    double? smoothing,
    double? glow,
    double? brightness,
    double? warmth,
    String? eyeLens,
    String? makeup,
  }) {
    return ZoonlBeautySettings(
      look: look ?? this.look,
      intensity: _unit(intensity ?? this.intensity),
      smoothing: _unit(smoothing ?? this.smoothing),
      glow: _unit(glow ?? this.glow),
      brightness: (brightness ?? this.brightness).clamp(-1.0, 1.0),
      warmth: (warmth ?? this.warmth).clamp(-1.0, 1.0),
      eyeLens: eyeLens ?? this.eyeLens,
      makeup: makeup ?? this.makeup,
    );
  }

  Map<String, Object> toJson() => <String, Object>{
        'look': look.name,
        'intensity': intensity,
        'smoothing': smoothing,
        'glow': glow,
        'brightness': brightness,
        'warmth': warmth,
        'eyeLens': eyeLens,
        'makeup': makeup,
      };

  factory ZoonlBeautySettings.fromJson(Map<String, dynamic> json) {
    return ZoonlBeautySettings(
      look: ZoonlBeautyLook.values.firstWhere(
        (value) => value.name == json['look'],
        orElse: () => ZoonlBeautyLook.natural,
      ),
      intensity: _unit(_number(json['intensity'], 0.35)),
      smoothing: _unit(_number(json['smoothing'], 0.15)),
      glow: _unit(_number(json['glow'], 0.15)),
      brightness: _number(json['brightness'], 0).clamp(-1.0, 1.0),
      warmth: _number(json['warmth'], 0).clamp(-1.0, 1.0),
      eyeLens: (json['eyeLens'] as String?) ?? 'none',
      makeup: (json['makeup'] as String?) ?? 'none',
    );
  }

  static double _unit(double value) => value.clamp(0.0, 1.0);
  static double _number(Object? value, double fallback) =>
      value is num ? value.toDouble() : fallback;
}

class ZoonlFaceStudioSettings {
  const ZoonlFaceStudioSettings({
    this.mode = ZoonlFaceStudioMode.off,
    this.assetId = 'none',
    this.showVirtualAvatarLabel = true,
  });

  final ZoonlFaceStudioMode mode;
  final String assetId;
  final bool showVirtualAvatarLabel;

  Map<String, Object> toJson() => <String, Object>{
        'mode': mode.name,
        'assetId': assetId,
        'showVirtualAvatarLabel': showVirtualAvatarLabel,
      };

  factory ZoonlFaceStudioSettings.fromJson(Map<String, dynamic> json) {
    return ZoonlFaceStudioSettings(
      mode: ZoonlFaceStudioMode.values.firstWhere(
        (value) => value.name == json['mode'],
        orElse: () => ZoonlFaceStudioMode.off,
      ),
      assetId: (json['assetId'] as String?) ?? 'none',
      showVirtualAvatarLabel: json['showVirtualAvatarLabel'] != false,
    );
  }
}

/// One profile can be saved and reused by Live and Short Video separately.
class ZoonlCameraPreset {
  const ZoonlCameraPreset({
    required this.id,
    required this.name,
    this.beauty = const ZoonlBeautySettings(),
    this.faceStudio = const ZoonlFaceStudioSettings(),
  });

  final String id;
  final String name;
  final ZoonlBeautySettings beauty;
  final ZoonlFaceStudioSettings faceStudio;

  Map<String, Object> toJson() => <String, Object>{
        'id': id,
        'name': name,
        'beauty': beauty.toJson(),
        'faceStudio': faceStudio.toJson(),
      };

  factory ZoonlCameraPreset.fromJson(Map<String, dynamic> json) {
    final beautyJson = json['beauty'];
    final faceJson = json['faceStudio'];
    return ZoonlCameraPreset(
      id: (json['id'] as String?) ?? 'default',
      name: (json['name'] as String?) ?? 'Natural',
      beauty: beautyJson is Map
          ? ZoonlBeautySettings.fromJson(
              Map<String, dynamic>.from(beautyJson),
            )
          : const ZoonlBeautySettings(),
      faceStudio: faceJson is Map
          ? ZoonlFaceStudioSettings.fromJson(
              Map<String, dynamic>.from(faceJson),
            )
          : const ZoonlFaceStudioSettings(),
    );
  }
}
