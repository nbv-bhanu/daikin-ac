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

  /// Returns null on success, or an error message on failure.
  /// [isPowerToggle] = true → repeat signal 8 times to simulate "hold 2-3 sec"
  static Future<String?> sendState(AcState state, {bool isPowerToggle = false}) async {
    // Older Daikin ACs (2012-2013) require receiving the power command
    // multiple times before the compressor engages — this mimics holding
    // the ON/OFF button on the physical remote for 2-3 seconds.
    final repeatCount = isPowerToggle ? 8 : 1;

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
      repeat:     repeatCount,
    );

    try {
      await _channel.invokeMethod<bool>('transmit', {
        'frequency': kDaikinFrequency,
        'pattern':   pattern,
      });
      return null; // success
    } on PlatformException catch (e) {
      return e.message ?? 'Platform error: ' + e.code;
    } catch (e) {
      return e.toString();
    }
  }
}
