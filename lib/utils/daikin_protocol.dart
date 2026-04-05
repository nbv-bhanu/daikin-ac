// Daikin Classic IR Protocol – ARC484B32
// Reference: https://gist.github.com/mildsunrise/a53bd50d529d92631fdaaed2368f903f
// 3 frames: ComfortFrame + TimeFrame + SettingsFrame (19 bytes total for frame 3)

const int kDaikinFrequency = 38000;

const int kTimeBurstHigh   = 3500;
const int kTimeBurstLow    = 1700;
const int kTimeSpacingFirst = 25000;
const int kTimeSpacingInter = 35000;
const int kTimeHigh        = 450;
const int kTimeLowZero     = 420;
const int kTimeLowOne      = 1286;

const List<int> kDaikinHeader = [0x11, 0xDA, 0x27, 0x00];

// Frame type codes
const int kCodeComfort  = 0xC5;
const int kCodeTime     = 0x42;
const int kCodeSettings = 0x00;

// Modes
const int kModeAuto = 0;
const int kModeDry  = 2;
const int kModeCool = 3;
const int kModeHeat = 4;
const int kModeFan  = 6;

// Fan speeds
const int kFanAuto   = 0xA;
const int kFanSilent = 0xB;
const int kFanLow    = 3;
const int kFanMed    = 5;
const int kFanHigh   = 7;

class DaikinProtocol {
  static int _checksum(List<int> data) =>
      data.fold(0, (s, b) => (s + b) & 0xFF);

  static List<int> _encodeFrame(int code, List<int> payload) {
    final data = [...kDaikinHeader, code, ...payload];
    return [...data, _checksum(data)];
  }

  // Comfort frame (2-byte payload; bit 12 = comfort)
  static List<int> encodeComfortFrame({bool comfort = false}) {
    final bits = comfort ? (1 << 12) : 0;
    return _encodeFrame(kCodeComfort, [bits & 0xFF, (bits >> 8) & 0xFF]);
  }

  // Time frame (2-byte payload; 12-bit minutes since midnight)
  static List<int> encodeTimeFrame({int minutes = 0}) {
    return _encodeFrame(kCodeTime, [minutes & 0xFF, (minutes >> 8) & 0x0F]);
  }

  // Settings frame – 13-byte payload (104 bits), packed LSB-first
  static List<int> encodeSettingsFrame({
    required bool power,
    int mode          = kModeAuto,
    int tempHalf      = 50,   // 25°C × 2
    int fanSpeed      = kFanAuto,
    int swingV        = 0,    // 0=off, 0xF=on
    int swingH        = 0,
    bool powerful     = false,
    bool silent       = false,
    bool economy      = false,
    bool ecoSensing   = false,
    bool timerOn      = false,
    bool timerOff     = false,
    int timerOnMins   = 0x600,
    int timerOffMins  = 0x600,
  }) {
    final payload = List<int>.filled(13, 0);
    int cursor = 0;

    void pack(int width, int value) {
      for (int i = 0; i < width; i++) {
        if ((value >> i) & 1 == 1) {
          payload[cursor >> 3] |= (1 << (cursor & 7));
        }
        cursor++;
      }
    }

    pack(1,  power    ? 1 : 0);   // bit 0
    pack(1,  timerOn  ? 1 : 0);   // bit 1
    pack(1,  timerOff ? 1 : 0);   // bit 2
    pack(1,  1);                   // bit 3: always 1 (_unknown3)
    pack(4,  mode);                // bits 4-7
    pack(8,  tempHalf);            // bits 8-15 (temperature in ½°C)
    pack(8,  0);                   // bits 16-23 (_zero16)
    pack(4,  swingV);              // bits 24-27
    pack(4,  fanSpeed);            // bits 28-31
    pack(4,  swingH);              // bits 32-35
    pack(4,  0);                   // bits 36-39 (_zero36)
    pack(12, timerOnMins);         // bits 40-51
    pack(12, timerOffMins);        // bits 52-63
    pack(1,  powerful  ? 1 : 0);  // bit 64
    pack(4,  0);                   // bits 65-68 (_zero65)
    pack(1,  silent    ? 1 : 0);  // bit 69
    pack(10, 0);                   // bits 70-79 (_zero70)
    pack(1,  1);                   // bit 80: always 1 (_unknown80)
    pack(3,  0);                   // bits 81-83 (_zero81)
    pack(4,  12);                  // bits 84-87: always 12 (_unknown84)
    pack(1,  0);                   // bit 88 (_zero88)
    pack(1,  ecoSensing ? 1 : 0); // bit 89
    pack(1,  economy    ? 1 : 0); // bit 90
    pack(4,  0);                   // bits 91-94 (_zero91)
    pack(1,  1);                   // bit 95: always 1 (_unknown95)
    pack(8,  0);                   // bits 96-103 (_zero96)

    return _encodeFrame(kCodeSettings, payload);
  }

  // Convert one frame (bytes) → IR timing list
  static List<int> _frameToSignal(List<int> frameBytes) {
    final sig = <int>[kTimeBurstHigh, kTimeBurstLow];
    for (final byte in frameBytes) {
      for (int i = 0; i < 8; i++) {
        sig.add(kTimeHigh);
        sig.add(((byte >> i) & 1) == 1 ? kTimeLowOne : kTimeLowZero);
      }
    }
    sig.add(kTimeHigh); // stop pulse
    return sig;
  }

  /// Build the complete IR signal (microsecond durations, starting HIGH)
  static List<int> buildSignal({
    required bool power,
    int  mode         = kModeAuto,
    double tempC      = 25.0,
    int  fanSpeed     = kFanAuto,
    bool swingV       = false,
    bool swingH       = false,
    bool powerful     = false,
    bool silent       = false,
    bool economy      = false,
    bool ecoSensing   = false,
    bool comfort      = false,
    bool timerOn      = false,
    bool timerOff     = false,
    int  timerOnMins  = 0x600,
    int  timerOffMins = 0x600,
  }) {
    final tempHalf = (tempC * 2).round().clamp(32, 60); // 16–30°C

    final f1 = encodeComfortFrame(comfort: comfort);
    final f2 = encodeTimeFrame();
    final f3 = encodeSettingsFrame(
      power:        power,
      mode:         mode,
      tempHalf:     tempHalf,
      fanSpeed:     fanSpeed,
      swingV:       swingV  ? 0xF : 0,
      swingH:       swingH  ? 0xF : 0,
      powerful:     powerful,
      silent:       silent,
      economy:      economy,
      ecoSensing:   ecoSensing,
      timerOn:      timerOn,
      timerOff:     timerOff,
      timerOnMins:  timerOnMins,
      timerOffMins: timerOffMins,
    );

    // Pre-transmission: 6 zero-bits without trailing space, then 25 ms gap
    final preBurst = <int>[];
    for (int i = 0; i < 6; i++) {
      preBurst.addAll([kTimeHigh, kTimeLowZero]);
    }
    preBurst.removeLast();        // remove final space
    preBurst.add(kTimeSpacingFirst);

    return [
      ...preBurst,
      ..._frameToSignal(f1), kTimeSpacingInter,
      ..._frameToSignal(f2), kTimeSpacingInter,
      ..._frameToSignal(f3),
    ];
  }
}
