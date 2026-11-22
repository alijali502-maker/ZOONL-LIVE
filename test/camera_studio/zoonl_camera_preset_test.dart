import 'package:flutter_test/flutter_test.dart';
import 'package:zoonl_live/camera_studio/zoonl_camera_preset.dart';

void main() {
  group('ZOONL camera preset settings', () {
    test('beauty controls stay inside safe supported ranges', () {
      final settings = const ZoonlBeautySettings().copyWith(
        smoothing: 4,
        glow: -1,
        brightness: 3,
        warmth: -3,
      );

      expect(settings.smoothing, 1);
      expect(settings.glow, 0);
      expect(settings.brightness, 1);
      expect(settings.warmth, -1);
    });

    test('preset round trips without coupling Beauty and Face Studio', () {
      const preset = ZoonlCameraPreset(
        id: 'natural-glow',
        name: 'Natural Glow',
        beauty: ZoonlBeautySettings(
          look: ZoonlBeautyLook.softGlow,
          smoothing: 0.2,
          glow: 0.4,
        ),
        faceStudio: ZoonlFaceStudioSettings(
          mode: ZoonlFaceStudioMode.avatar,
          assetId: 'avatar_01',
        ),
      );

      final restored = ZoonlCameraPreset.fromJson(preset.toJson());

      expect(restored.id, preset.id);
      expect(restored.beauty.look, ZoonlBeautyLook.softGlow);
      expect(restored.beauty.smoothing, 0.2);
      expect(restored.faceStudio.mode, ZoonlFaceStudioMode.avatar);
      expect(restored.faceStudio.assetId, 'avatar_01');
    });

    test('unknown saved values safely fall back to Natural and Off', () {
      final restored = ZoonlCameraPreset.fromJson(<String, dynamic>{
        'id': 'old',
        'name': 'Old preset',
        'beauty': <String, dynamic>{'look': 'removed-look'},
        'faceStudio': <String, dynamic>{'mode': 'removed-mode'},
      });

      expect(restored.beauty.look, ZoonlBeautyLook.natural);
      expect(restored.faceStudio.mode, ZoonlFaceStudioMode.off);
    });
  });
}
