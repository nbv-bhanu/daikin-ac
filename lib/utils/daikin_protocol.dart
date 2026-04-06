// Daikin Classic IR Protocol – ARC484B32
// Structure confirmed by real remote captures:
//   stackoverflow.com/questions/72725599 (web:153)
//   github.com/YSYouJack/Daikin-ir-control-rpi (web:32)
//
// Signal layout:
//   PRE-BURST (6 zero-bits minus last space + 25ms gap)
//   → Frame1 (8 bytes fixed) + 35ms gap
//   → Frame2 (8 bytes fixed) + 35ms gap
//   → Frame3 (19 bytes command)
//   Repeat entire sequence N times for "hold" behaviour

const int kDaikinFrequency = 38000; // 38 kHz

// Timing from real captures (YSYouJack + StackOverflow)
const int kHdrMark   = 3500;   // frame header mark
const int kHdrSpace  = 1700;   // frame header space
const int kBitMark   = 440;    // every bit mark
const int kOneSpace  = 1300;   // bit-1 space
const int kZeroSpace = 430;    // bit-0 space
const int kPreBit    = 440;    // pre-burst pulse
const int kPreGap    = 430;    // pre-burst gap
const int kStartGap  = 25000; // gap after pre-burst
const int kFrameGap  = 35000; // gap between frames

// Fixed frames (verified against IRremoteESP8266 + community)
const List<int> kFrame1 = [0x11,0xDA,0x27,0x00,0xC5,0x00,0x00,0xD7];
const List<int> kFrame2 = [0x11,0xDA,0x27,0x00,0x42,0x00,0x00,0x54];

// Mode codes
const int kModeAuto = 0;
const int kModeDry  = 2;
const int kModeCool = 3;
const int kModeHeat = 4;
const int kModeFan  = 6;

// Fan speed codes
const int kFanAuto   = 0xA;
const int kFanSilent = 0xB;

class DaikinProtocol {

  static int _checksum(List<int> data) =>
      data.fold(0, (s, b) => (s + b) & 0xFF);

  // ── Build 19-byte settings frame ────────────────────────────────────────
  static List<int> buildSettingsFrame({
    required bool power,
    int  mode       = kModeAuto,
    int  tempHalf   = 50,   // 25°C × 2
    int  fanSpeed   = kFanAuto,
    int  swingV     = 0,    // 0=off, 0xF=on
    int  swingH     = 0,
    bool powerful   = false,
    bool silent     = false,
    bool economy    = false,
    bool ecoSensing = false,
  }) {
    final s = List<int>.filled(19, 0);
    s[0] = 0x11; s[1] = 0xDA; s[2] = 0x27; s[3] = 0x00;
    s[4] = 0x00; // settings frame code

    // [5] power(bit0) | always-1(bit3) | mode(bits7-4)
    s[5]  = (power ? 0x01 : 0x00) | 0x08 | ((mode & 0x0F) << 4);
    // [6] temperature in half-degrees (25°C → 50 = 0x32)
    s[6]  = tempHalf.clamp(32, 60);
    s[7]  = 0x00;
    // [8] swingV(lower nibble) | fanSpeed(upper nibble)
    s[8]  = (swingV & 0x0F) | ((fanSpeed & 0x0F) << 4);
    // [9] swingH(lower nibble)
    s[9]  = swingH & 0x0F;
    s[10] = 0x00; s[11] = 0x00;
    s[12] = 0xC1; // default clock display byte
    s[13] = 0x80;
    s[14] = 0x00; s[15] = 0x00; s[16] = 0x00;
    // [17] feature flags
    s[17] = (powerful    ? 0x01 : 0x00)
          | (ecoSensing  ? 0x02 : 0x00)
          | (economy     ? 0x04 : 0x00)
          | (silent      ? 0x20 : 0x00);
    // [18] checksum
    s[18] = _checksum(s.sublist(0, 18));
    return s;
  }

  // ── Convert frame bytes → IR timing list (LSB first per byte) ────────────
  static List<int> _frameToSignal(List<int> frameBytes) {
    final sig = <int>[kHdrMark, kHdrSpace];
    for (final byte in frameBytes) {
      for (int i = 0; i < 8; i++) {
        sig.add(kBitMark);
        sig.add(((byte >> i) & 1) == 1 ? kOneSpace : kZeroSpace);
      }
    }
    sig.add(kBitMark); // stop bit
    return sig;
  }

  // ── Build one full transmission (pre-burst + 3 frames) ───────────────────
  static List<int> _buildOnce({
    required bool power,
    int  mode       = kModeAuto,
    double tempC    = 25.0,
    int  fanSpeed   = kFanAuto,
    bool swingV     = false,
    bool swingH     = false,
    bool powerful   = false,
    bool silent     = false,
    bool economy    = false,
    bool ecoSensing = false,
  }) {
    final tempHalf = (tempC * 2).round().clamp(32, 60);
    final frame3 = buildSettingsFrame(
      power: power, mode: mode, tempHalf: tempHalf,
      fanSpeed: fanSpeed,
      swingV: swingV ? 0xF : 0, swingH: swingH ? 0xF : 0,
      powerful: powerful, silent: silent,
      economy: economy, ecoSensing: ecoSensing,
    );

    // Pre-burst: 6 × [440 ON + 430 OFF] minus last OFF, then 25000 gap
    final pre = <int>[];
    for (int i = 0; i < 6; i++) {
      pre.addAll([kPreBit, kPreGap]);
    }
    pre.removeLast();        // remove final gap
    pre.add(kStartGap);      // 25 ms silence

    return [
      ...pre,
      ..._frameToSignal(kFrame1), kFrameGap,
      ..._frameToSignal(kFrame2), kFrameGap,
      ..._frameToSignal(frame3),
    ];
  }

  /// Build signal repeated [count] times.
  /// For POWER ON of older Daikin (2012-2013), use count=8 to mimic
  /// "press and hold for 2-3 seconds" behaviour.
  static List<int> buildSignal({
    required bool power,
    int    mode       = kModeAuto,
    double tempC      = 25.0,
    int    fanSpeed   = kFanAuto,
    bool   swingV     = false,
    bool   swingH     = false,
    bool   powerful   = false,
    bool   silent     = false,
    bool   economy    = false,
    bool   ecoSensing = false,
    int    repeat     = 1,
  }) {
    final single = _buildOnce(
      power: power, mode: mode, tempC: tempC, fanSpeed: fanSpeed,
      swingV: swingV, swingH: swingH, powerful: powerful,
      silent: silent, economy: economy, ecoSensing: ecoSensing,
    );
    if (repeat <= 1) return single;

    // Stitch repetitions together with a 100ms inter-repetition space
    final full = <int>[...single];
    for (int r = 1; r < repeat; r++) {
      full.add(100000); // 100ms gap between repetitions
      full.addAll(single);
    }
    return full;
  }
}
