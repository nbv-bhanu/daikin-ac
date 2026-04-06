import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ac_state.dart';
import '../services/ir_service.dart';
import '../utils/daikin_protocol.dart';

class AcControlScreen extends StatefulWidget {
  const AcControlScreen({super.key});
  @override
  State<AcControlScreen> createState() => _AcControlScreenState();
}

class _AcControlScreenState extends State<AcControlScreen> {
  AcState _state = AcState();
  bool _hasIr   = false;
  bool _sending  = false;

  static const Color _bg     = Color(0xFF0D1117);
  static const Color _card   = Color(0xFF161B22);
  static const Color _blue   = Color(0xFF0078D7);
  static const Color _green  = Color(0xFF238636);
  static const Color _red    = Color(0xFFDA3633);
  static const Color _dim    = Color(0xFF8B949E);
  static const Color _border = Color(0xFF30363D);

  @override
  void initState() {
    super.initState();
    IrService.hasIrBlaster().then((v) => setState(() => _hasIr = v));
  }

  // ── Send IR signal and show prominent result feedback ─────────────────────
  Future<void> _send(AcState newState) async {
    if (_sending) return;
    setState(() { _state = newState; _sending = true; });

    final error = await IrService.sendState(newState);

    setState(() => _sending = false);
    if (!mounted) return;

    if (error == null) {
      final info = newState.power
          ? 'ON  |  ' + newState.modeLabel + '  |  ' + newState.temperature.toStringAsFixed(0) + '°C'
          : 'OFF';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text('Signal sent → ' + info),
        ]),
        backgroundColor: _green,
        duration: const Duration(seconds: 2),
      ));
    } else {
      _showErrorDialog(error);
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.error_outline, color: Color(0xFFDA3633)),
          SizedBox(width: 8),
          Text('IR Send Failed', style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(error,
                style: const TextStyle(color: Colors.orange, fontSize: 12, fontFamily: 'monospace')),
            ),
            const SizedBox(height: 14),
            const Text('Try this:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
              '1. Point TOP EDGE of phone at AC\n'
              '2. Keep 30–50 cm from the AC unit\n'
              '3. No obstructions between phone & AC\n'
              '4. Tap Test IR to confirm hardware',
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 12, height: 1.7),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); _sendIrTest(); },
            child: const Text('Test IR', style: TextStyle(color: Color(0xFF8B949E))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFF0078D7))),
          ),
        ],
      ),
    );
  }

  // ── IR hardware test: NEC test pulse via IrService ─────────────────────────
  Future<void> _sendIrTest() async {
    final testPattern = [
      9000, 4500, 560, 560, 560, 1690, 560, 560, 560, 560,
      560, 560, 560, 560, 560, 560, 560, 560, 560, 1690, 560, 1690, 560, 1690,
      560, 1690, 560, 1690, 560, 1690, 560, 1690, 560, 560, 560, 1690, 560, 560,
      560, 560, 560, 560, 560, 560, 560, 560, 560, 560, 560, 1690, 560, 560,
      560, 1690, 560, 1690, 560, 1690, 560, 1690, 560, 1690, 560, 1690, 560, 1690, 560,
    ];
    try {
      await const MethodChannel('com.daikin.accontroller/ir')
          .invokeMethod('transmit', {'frequency': 38000, 'pattern': testPattern});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('IR test pulse sent! If AC beeped, hardware is working.'),
          backgroundColor: Color(0xFF0078D7),
          duration: Duration(seconds: 3),
        ));
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('IR hardware test FAILED: ' + (e.message ?? e.code)),
          backgroundColor: _red,
        ));
      }
    }
  }

  // ─── UI helpers ────────────────────────────────────────────────────────────
  Widget _modeBtn(String label, int mode, IconData icon) {
    final active = _state.mode == mode && _state.power;
    return GestureDetector(
      onTap: () => _send(_state.copyWith(mode: mode, power: true)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 58, height: 62,
        decoration: BoxDecoration(
          color: active ? _blue : _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? _blue : _border),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: active ? Colors.white : _dim, size: 20),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
              color: active ? Colors.white : _dim,
              fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _fanBtn(String label, int speed) {
    final active = _state.fanSpeed == speed;
    return GestureDetector(
      onTap: () => _send(_state.copyWith(fanSpeed: speed)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _blue : _card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? _blue : _border),
        ),
        child: Text(label, style: TextStyle(
            color: active ? Colors.white : _dim,
            fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 50,
        decoration: BoxDecoration(
          color: active ? _blue.withAlpha(50) : _card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? _blue : _border),
        ),
        child: Center(
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(color: active ? _blue : _dim,
                  fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  // ─── Main build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(children: [

          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // Header
                Row(children: [
                  const Icon(Icons.ac_unit, color: Color(0xFF0078D7), size: 22),
                  const SizedBox(width: 8),
                  const Text('Daikin AC',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _sendIrTest,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _hasIr ? _green.withAlpha(40) : _red.withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _hasIr ? _green : _red),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.sensors, size: 12, color: _hasIr ? _green : _red),
                        const SizedBox(width: 4),
                        Text(_hasIr ? 'IR ✓ Test' : 'Test IR',
                            style: TextStyle(color: _hasIr ? _green : _red, fontSize: 11)),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),

                // Temperature card
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border),
                  ),
                  child: Column(children: [
                    Text(
                      _state.power ? _state.modeLabel.toUpperCase() : 'STANDBY',
                      style: TextStyle(
                          color: _state.power ? _blue : _dim,
                          fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      GestureDetector(
                        onTap: () {
                          if (_state.temperature > 16) {
                            _send(_state.copyWith(temperature: _state.temperature - 1, power: true));
                          }
                        },
                        child: Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: _bg, borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _border),
                          ),
                          child: const Icon(Icons.remove, color: Colors.white70, size: 26),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Column(children: [
                        Text(
                          _state.temperature.toStringAsFixed(0) + '°C',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 54, fontWeight: FontWeight.w200),
                        ),
                        Text('Fan: ' + _state.fanLabel,
                            style: TextStyle(color: _dim, fontSize: 11)),
                      ]),
                      const SizedBox(width: 20),
                      GestureDetector(
                        onTap: () {
                          if (_state.temperature < 30) {
                            _send(_state.copyWith(temperature: _state.temperature + 1, power: true));
                          }
                        },
                        child: Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: _bg, borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _border),
                          ),
                          child: const Icon(Icons.add, color: Colors.white70, size: 26),
                        ),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),

                // Mode
                const Text('MODE',
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 11, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _modeBtn('Auto', kModeAuto, Icons.autorenew),
                  _modeBtn('Cool', kModeCool, Icons.ac_unit),
                  _modeBtn('Heat', kModeHeat, Icons.local_fire_department),
                  _modeBtn('Dry',  kModeDry,  Icons.water_drop),
                  _modeBtn('Fan',  kModeFan,  Icons.wind_power),
                ]),
                const SizedBox(height: 16),

                // Fan speed
                const Text('FAN SPEED',
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 11, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _fanBtn('Auto', kFanAuto),
                  _fanBtn('1', 3),
                  _fanBtn('2', 4),
                  _fanBtn('3', 5),
                  _fanBtn('4', 6),
                  _fanBtn('5', 7),
                  _fanBtn('SIL', kFanSilent),
                ]),
                const SizedBox(height: 16),

                // Swing
                const Text('SWING',
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 11, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _toggleBtn(
                      '↕  Swing Vertical', _state.swingV,
                      () => _send(_state.copyWith(swingV: !_state.swingV)))),
                  const SizedBox(width: 10),
                  Expanded(child: _toggleBtn(
                      '↔  Swing Horizontal', _state.swingH,
                      () => _send(_state.copyWith(swingH: !_state.swingH)))),
                ]),
                const SizedBox(height: 16),

                // Special modes
                const Text('SPECIAL MODES',
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 11, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2, shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10, crossAxisSpacing: 10,
                  childAspectRatio: 3.2,
                  children: [
                    _toggleBtn('⚡ POWERCHILL', _state.powerful,
                        () => _send(_state.copyWith(powerful: !_state.powerful))),
                    _toggleBtn('🌿 ECONO', _state.economy,
                        () => _send(_state.copyWith(economy: !_state.economy))),
                    _toggleBtn('🤫 SILENT', _state.silent,
                        () => _send(_state.copyWith(silent: !_state.silent))),
                    _toggleBtn('📡 ECO SENSE', _state.ecoSensing,
                        () => _send(_state.copyWith(ecoSensing: !_state.ecoSensing))),
                    _toggleBtn('🌊 COANDA', _state.comfort,
                        () => _send(_state.copyWith(comfort: !_state.comfort))),
                    _toggleBtn('💤 GOOD SLEEP', _state.silent,
                        () => _send(_state.copyWith(silent: !_state.silent))),
                  ],
                ),
              ],
            ),
          ),

          // Floating POWER button
          Positioned(
            bottom: 16, left: 16, right: 16,
            child: GestureDetector(
              onTap: _sending ? null : () => _send(_state.copyWith(power: !_state.power)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 64,
                decoration: BoxDecoration(
                  color: _state.power ? _green : _red,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(
                    color: (_state.power ? _green : _red).withAlpha(110),
                    blurRadius: 20, spreadRadius: 2,
                  )],
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (_sending)
                    const SizedBox(width: 24, height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  else
                    const Icon(Icons.power_settings_new, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    _sending ? 'SENDING...' : (_state.power ? 'TURN OFF' : 'TURN ON'),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                ]),
              ),
            ),
          ),

        ]),
      ),
    );
  }
}
