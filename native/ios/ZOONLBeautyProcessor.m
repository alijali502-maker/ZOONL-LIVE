#import "ZOONLBeautyProcessor.h"
#import <WebRTC/WebRTC.h>
#import <flutter_webrtc/FlutterWebRTCPlugin.h>
#import <flutter_webrtc/LocalVideoTrack.h>
#import <stdatomic.h>
#import <math.h>
#import <string.h>

@interface ZOONLBeautyFrameProcessor : NSObject <ExternalVideoProcessingDelegate>
- (void)configure:(NSDictionary *)settings;
@end

@implementation ZOONLBeautyFrameProcessor {
  atomic_int _smoothing;
  atomic_int _glow;
  atomic_int _brightness;
  atomic_int _warmth;
  atomic_int _saturation;
  atomic_int _contrast;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    atomic_init(&_smoothing, 0);
    atomic_init(&_glow, 0);
    atomic_init(&_brightness, 0);
    atomic_init(&_warmth, 0);
    atomic_init(&_saturation, 1000);
    atomic_init(&_contrast, 1000);
  }
  return self;
}

- (void)configure:(NSDictionary *)settings {
  double intensity = [settings[@"intensity"] respondsToSelector:@selector(doubleValue)]
      ? [settings[@"intensity"] doubleValue] : 0.35;
  intensity = fmax(0.0, fmin(1.0, intensity));
  double smoothing = [settings[@"smoothing"] doubleValue] * intensity;
  double glow = [settings[@"glow"] doubleValue] * intensity;
  double brightness = [settings[@"brightness"] doubleValue] * intensity;
  double warmth = [settings[@"warmth"] doubleValue] * intensity;
  NSString *look = [settings[@"look"] isKindOfClass:NSString.class] ? settings[@"look"] : @"Natural";
  int saturation = [look isEqualToString:@"Vivid"] ? 1120 : 1000;
  int contrast = [look isEqualToString:@"Cinema"] ? 1070 : 1000;
  if ([look isEqualToString:@"Mono"]) saturation = 0;
  atomic_store(&_smoothing, (int)lrint(fmax(0, fmin(1, smoothing)) * 180));
  atomic_store(&_glow, (int)lrint(fmax(0, fmin(1, glow)) * 1000));
  atomic_store(&_brightness, (int)lrint(fmax(-1, fmin(1, brightness)) * 22));
  atomic_store(&_warmth, (int)lrint(fmax(-1, fmin(1, warmth)) * 1000));
  atomic_store(&_saturation, saturation);
  atomic_store(&_contrast, contrast);
}

- (RTC_OBJC_TYPE(RTCVideoFrame) *)onFrame:(RTC_OBJC_TYPE(RTCVideoFrame) *)frame {
  int smooth = atomic_load(&_smoothing);
  int glow = atomic_load(&_glow);
  int lift = atomic_load(&_brightness);
  int warm = atomic_load(&_warmth);
  int saturation = atomic_load(&_saturation);
  int contrast = atomic_load(&_contrast);
  if (smooth == 0 && glow == 0 && lift == 0 && warm == 0 &&
      saturation == 1000 && contrast == 1000) return frame;

  id<RTC_OBJC_TYPE(RTCI420Buffer)> src = [frame.buffer toI420];
  if (src == nil) return frame;
  int width = src.width, height = src.height;
  int chromaWidth = (width + 1) / 2;
  int chromaHeight = (height + 1) / 2;
  RTC_OBJC_TYPE(RTCMutableI420Buffer) *dst =
      [[RTC_OBJC_TYPE(RTCMutableI420Buffer) alloc] initWithWidth:width height:height];

  for (int y = 0; y < height; y++) {
    const uint8_t *row = src.dataY + y * src.strideY;
    uint8_t *out = dst.mutableDataY + y * dst.strideY;
    for (int x = 0; x < width; x++) {
      double center = row[x];
      double value = center;
      if (smooth > 0) {
        int sum = (int)center * 4, count = 4;
        if (x > 0) { sum += row[x - 1]; count++; }
        if (x + 1 < width) { sum += row[x + 1]; count++; }
        if (y > 0) { sum += src.dataY[(y - 1) * src.strideY + x]; count++; }
        if (y + 1 < height) { sum += src.dataY[(y + 1) * src.strideY + x]; count++; }
        value = center * (1.0 - smooth / 1000.0) +
                (sum / (double)count) * (smooth / 1000.0);
      }
      value += lift;
      value += fmax(0.0, value - 112.0) * (glow / 1000.0) * 0.055;
      value = 128.0 + (value - 128.0) * (contrast / 1000.0);
      out[x] = (uint8_t)fmax(0, fmin(255, lrint(value)));
    }
  }

  for (int y = 0; y < chromaHeight; y++) {
    const uint8_t *inU = src.dataU + y * src.strideU;
    const uint8_t *inV = src.dataV + y * src.strideV;
    uint8_t *outU = dst.mutableDataU + y * dst.strideU;
    uint8_t *outV = dst.mutableDataV + y * dst.strideV;
    for (int x = 0; x < chromaWidth; x++) {
      double u = 128.0 + ((int)inU[x] - 128.0) * (saturation / 1000.0) - warm * 0.002;
      double v = 128.0 + ((int)inV[x] - 128.0) * (saturation / 1000.0) + warm * 0.003;
      outU[x] = (uint8_t)fmax(0, fmin(255, lrint(u)));
      outV[x] = (uint8_t)fmax(0, fmin(255, lrint(v)));
    }
  }

  return [[RTC_OBJC_TYPE(RTCVideoFrame) alloc] initWithBuffer:dst
                                                     rotation:frame.rotation
                                                  timeStampNs:frame.timeStampNs];
}
@end

@implementation ZOONLBeautyProcessorPlugin {
  NSMutableDictionary<NSString *, ZOONLBeautyFrameProcessor *> *_processors;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:@"zoonl.live/beauty"
                                  binaryMessenger:registrar.messenger];
  ZOONLBeautyProcessorPlugin *instance = [[ZOONLBeautyProcessorPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)init {
  self = [super init];
  if (self) _processors = [NSMutableDictionary new];
  return self;
}

- (LocalVideoTrack *)localTrack:(NSString *)trackId {
  id<LocalTrack> track = FlutterWebRTCPlugin.sharedSingleton.localTracks[trackId];
  return [track isKindOfClass:LocalVideoTrack.class] ? (LocalVideoTrack *)track : nil;
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  NSDictionary *args = [call.arguments isKindOfClass:NSDictionary.class] ? call.arguments : nil;
  NSString *trackId = args[@"trackId"];
  if (![trackId isKindOfClass:NSString.class]) {
    result([FlutterError errorWithCode:@"bad_args" message:@"trackId is required" details:nil]);
    return;
  }
  if ([call.method isEqualToString:@"addBeauty"]) {
    ZOONLBeautyFrameProcessor *processor = _processors[trackId];
    if (processor == nil) {
      LocalVideoTrack *track = [self localTrack:trackId];
      if (track == nil) {
        result([FlutterError errorWithCode:@"no_track"
                                   message:[@"Local camera track not found: " stringByAppendingString:trackId]
                                   details:nil]);
        return;
      }
      processor = [ZOONLBeautyFrameProcessor new];
      [track addProcessing:processor];
      _processors[trackId] = processor;
    }
    [processor configure:args ?: @{}];
    result(nil);
  } else if ([call.method isEqualToString:@"removeBeauty"]) {
    ZOONLBeautyFrameProcessor *processor = _processors[trackId];
    if (processor != nil) {
      [[self localTrack:trackId] removeProcessing:processor];
      [_processors removeObjectForKey:trackId];
    }
    result(@(processor != nil));
  } else {
    result(FlutterMethodNotImplemented);
  }
}
@end
