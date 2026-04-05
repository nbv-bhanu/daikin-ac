import 'package:flutter/services.dart';
import '../utils/daikin_protocol.dart';
import '../models/ac_state.dart';

class IrService {
  static const _channel = MethodChannel('com.daikin.accontroller/ir');

  static Future<bool> hasIrBlaster() async {
    try {
      return await _channel.invokeMethod<bool>('hasIrBlaster') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> sendState(AcState state) async {
    final pattern = DaikinProtocol.buildSignal(
      power:      state.power,
      mode:       state.mode,
      tempC:      state.temperature,
      fanSpeed:   state.fanSpeed,
      swingV:     state.swingV,
      swingH:     state.swingH,
      powerful:   state.powerful,
      silent:     state.silent,
      economy:    state.economy,
      ecoSensing: state.ecoSensing,
      comfort:    state.comfort,
    );
    try {
      await _channel.invokeMethod('transmit', {
        'frequency': kDaikinFrequency,
        'pattern':   pattern,
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}
