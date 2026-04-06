import 'dart:async';
import 'package:flutter/services.dart';
import '../utils/daikin_protocol.dart';
import '../models/ac_state.dart';

class IrService {
  static const _ch = MethodChannel('com.daikin.accontroller/ir');

  // ── Hardware check ────────────────────────────────────────────────────
  static Future<bool> hasIrBlaster() async {
    try { return await _ch.invokeMethod<bool>('hasIrBlaster') ?? false; }
    catch (_) { return false; }
  }

  // ── Core: send ONE signal (must be < 2 sec for Android hardware limit) ─
  static Future<String?> _transmitOnce(List<int> pattern) async {
    try {
      await _ch.invokeMethod<bool>('transmit', {
        'frequency': kDaikinFrequency,
        'pattern':   pattern,
      });
      return null;
    } on PlatformException catch (e) {
      return e.message ?? 'Platform error [' + e.code + ']';
    } catch (e) {
      return e.toString();
    }
  }

  // ── Public API ────────────────────────────────────────────────────────
  /// Send once  (mode/temp/fan buttons).
  static Future<String?> sendOnce(AcState s) async {
    return _transmitOnce(_buildPattern(s));
  }

  /// Send [count] times, each separated by [gapMs] milliseconds.
  /// MUST NOT embed the gap in the IR pattern — Android drops patterns > 2 s.
  /// count=8, gapMs=200  →  simulates ~2.5 sec physical button hold.
  static Future<String?> sendRepeat(AcState s,
      {int count = 8, int gapMs = 200}) async {
    final pattern = _buildPattern(s);
    for (int i = 0; i < count; i++) {
      final err = await _transmitOnce(pattern);
      if (err != null) return err;
      if (i < count - 1) {
        await Future.delayed(Duration(milliseconds: gapMs));
      }
    }
    return null;
  }

  static List<int> _buildPattern(AcState s) => DaikinProtocol.buildSignal(
    power:      s.power,
    mode:       s.mode,
    tempC:      s.temperature,
    fanSpeed:   s.fanSpeed,
    swingV:     s.swingV,
    swingH:     s.swingH,
    powerful:   s.powerful,
    silent:     s.silent,
    economy:    s.economy,
    ecoSensing: s.ecoSensing,
  );
}
