// Daikin Classic IR Protocol – ARC484B32 / ARC484A series
// Framing based on IRremoteESP8266 (crankyoldgit) – most hardware-tested implementation
// https://github.com/crankyoldgit/IRremoteESP8266/blob/master/src/ir_Daikin.cpp

const int kDaikinFrequency = 38000; // 38 kHz carrier

// Timing constants (microseconds) – from IRremoteESP8266
const int kDaikinHdrMark   = 3650;
const int kDaikinHdrSpace  = 1623;
const int kDaikinBitMark   = 428;
const int kDaikinOneSpace  = 1320;
const int kDaikinZeroSpace = 428;
const int kDaikinGap       = 29000;  // inter-frame / preamble gap

// Fixed frame bytes (verified against IRremoteESP8266 kDaikinFirstFrame/SecondFrame)
const List<int> kDaikinFrame1 = [0x11, 0xDA, 0x27, 0x00, 0xC5, 0x00, 0x00, 0xD7];
const List<int> kDaikinFrame2 = [0x11, 0xDA, 0x27, 0x00, 0x42, 0x00, 0x00, 0x54];

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

  // Build the 19-byte settings frame
  // Byte layout (verified from IRremoteESP8266 + community captures):
  //   [0-3]: 0x11 0xDA 0x27 0x00 (fixed header)
  //   [4]  : code = 0x00
  //   [5]  : power(bit0) | timerOn(bit1) | timerOff(bit2) | 1(bit3) | mode(bits7-4)
  //   [6]  : temperature × 2  (e.g. 25°C → 0x32)
  //   [7]  : 0x00
  //   [8]  : swingV(bits3-0) | fanSpeed(bits7-4)
  //   [9]  : swingH(bits3-0)
  //   [10-16]: timer & feature bytes
  //   [17] : powerful(bit0) | silent(bit5) | economy(bit2) | ecoSensing(bit1)
  //   [18] : checksum
  static List<int> buildSettingsFrame({
    required bool power,
    int  mode        = kModeAuto,
    int  tempHalf    = 50,    // 25°C × 2 = 50
    int  fanSpeed    = kFanAuto,
    int  swingV      = 0,     // 0=off, 0xF=on
    int  swingH      = 0,
    bool powerful    = false,
    bool silent      = false,
    bool economy     = false,
    bool ecoSensing  = false,
  }) {
    final s = List<int>.filled(19, 0);
    s[0] = 0x11;
    s[1] = 0xDA;
    s[2] = 0x27;
    s[3] = 0x00;
    s[4] = 0x00; // settings frame code

    // Byte 5: power | timerOn | timerOff | always-1 | mode
    s[5] = (power ? 0x01 : 0x00)
         | 0x08                        // bit3 always 1
         | ((mode & 0x0F) << 4);

    // Byte 6: temperature in half-degrees
    s[6] = tempHalf & 0xFF;

    s[7] = 0x00;

    // Byte 8: swingV (lower nibble) | fanSpeed (upper nibble)
    s[8] = (swingV & 0x0F) | ((fanSpeed & 0x0F) << 4);

    // Byte 9: swingH (lower nibble)
    s[9] = swingH & 0x0F;

    s[10] = 0x00;
    s[11] = 0x00;
    s[12] = 0xC1; // default clock/display byte
    s[13] = 0x80;
    s[14] = 0x00;
    s[15] = 0x00;
    s[16] = 0x00;

    // Byte 17: feature flags
    s[17] = (powerful    ? 0x01 : 0x00)
          | (ecoSensing  ? 0x02 : 0x00)
          | (economy     ? 0x04 : 0x00)
          | (silent      ? 0x20 : 0x00);

    // Byte 18: checksum
    s[18] = _checksum(s.sublist(0, 18));
    return s;
  }

  // Convert bytes to IR timing list (IRremoteESP8266 structure)
  // Each frame = [preamble: 3650+29000] + [header: 3650+1623] + [bits LSB-first] + [stop: 428]
  // Non-last frames add trailing 29000µs gap after stop bit
  static List<int> _frameToSignal(List<int> frameBytes, {bool isLast = false}) {
    final sig = <int>[];
    // Preamble (sendDaikinGap equivalent)
    sig.addAll([kDaikinHdrMark, kDaikinGap]);
    // Frame header
    sig.addAll([kDaikinHdrMark, kDaikinHdrSpace]);
    // Data bits – LSB first for each byte
    for (final byte in frameBytes) {
      for (int i = 0; i < 8; i++) {
        sig.add(kDaikinBitMark);
        sig.add(((byte >> i) & 1) == 1 ? kDaikinOneSpace : kDaikinZeroSpace);
      }
    }
    // Stop bit
    sig.add(kDaikinBitMark);
    // Trailing gap for frames 1 & 2
    if (!isLast) sig.add(kDaikinGap);
    return sig;
  }

  /// Build the complete IR pattern (microsecond durations, starts with MARK)
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
  }) {
    final tempHalf = (tempC * 2).round().clamp(32, 60); // 16–30°C

    final frame3 = buildSettingsFrame(
      power:      power,
      mode:       mode,
      tempHalf:   tempHalf,
      fanSpeed:   fanSpeed,
      swingV:     swingV ? 0xF : 0,
      swingH:     swingH ? 0xF : 0,
      powerful:   powerful,
      silent:     silent,
      economy:    economy,
      ecoSensing: ecoSensing,
    );

    return [
      ..._frameToSignal(kDaikinFrame1, isLast: false),
      ..._frameToSignal(kDaikinFrame2, isLast: false),
      ..._frameToSignal(frame3,        isLast: true),
    ];
  }
}
