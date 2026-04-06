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

  /// Returns null on success, or an error string on failure
  static Future<String?> sendState(AcState state) async {
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
    );
    try {
      // NOTE: We always attempt transmit even if hasIrEmitter() returned false
      // because MIUI on some Redmi phones incorrectly reports false but IR still works.
      await _channel.invokeMethod('transmit', {
        'frequency': kDaikinFrequency,
        'pattern':   pattern,
      });
      return null; // success
    } on PlatformException catch (e) {
      return e.message ?? 'Unknown platform error (code: \${e.code})';
    } catch (e) {
      return e.toString();
    }
  }
}
