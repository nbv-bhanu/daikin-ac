import '../utils/daikin_protocol.dart';

class AcState {
  bool power;
  int  mode;
  double temperature;
  int  fanSpeed;
  bool swingV;
  bool swingH;
  bool powerful;
  bool silent;
  bool economy;
  bool ecoSensing;
  bool comfort;

  AcState({
    this.power       = false,
    this.mode        = kModeAuto,
    this.temperature = 25.0,
    this.fanSpeed    = kFanAuto,
    this.swingV      = false,
    this.swingH      = false,
    this.powerful    = false,
    this.silent      = false,
    this.economy     = false,
    this.ecoSensing  = false,
    this.comfort     = false,
  });

  AcState copyWith({
    bool?   power,
    int?    mode,
    double? temperature,
    int?    fanSpeed,
    bool?   swingV,
    bool?   swingH,
    bool?   powerful,
    bool?   silent,
    bool?   economy,
    bool?   ecoSensing,
    bool?   comfort,
  }) => AcState(
    power:       power       ?? this.power,
    mode:        mode        ?? this.mode,
    temperature: temperature ?? this.temperature,
    fanSpeed:    fanSpeed    ?? this.fanSpeed,
    swingV:      swingV      ?? this.swingV,
    swingH:      swingH      ?? this.swingH,
    powerful:    powerful    ?? this.powerful,
    silent:      silent      ?? this.silent,
    economy:     economy     ?? this.economy,
    ecoSensing:  ecoSensing  ?? this.ecoSensing,
    comfort:     comfort     ?? this.comfort,
  );

  String get modeLabel {
    switch (mode) {
      case kModeAuto: return 'Auto';
      case kModeCool: return 'Cool';
      case kModeHeat: return 'Heat';
      case kModeDry:  return 'Dry';
      case kModeFan:  return 'Fan';
      default:        return 'Auto';
    }
  }

  String get fanLabel {
    switch (fanSpeed) {
      case kFanAuto:   return 'Auto';
      case kFanSilent: return 'Silent';
      case 3:          return '1';
      case 4:          return '2';
      case 5:          return '3';
      case 6:          return '4';
      case 7:          return '5';
      default:         return 'Auto';
    }
  }
}
