import 'package:flutter/material.dart';
import '../models/ac_state.dart';
import '../services/ir_service.dart';
import '../utils/daikin_protocol.dart';

class AcControlScreen extends StatefulWidget {
  const AcControlScreen({super.key});
  @override State<AcControlScreen> createState() => _AcControlScreenState();
}

class _AcControlScreenState extends State<AcControlScreen> {
  AcState _state = AcState();
  bool _hasIr = false;
  String _lastMsg = '';
  bool _sending = false;

  static const Color _bg    = Color(0xFF0D1117);
  static const Color _card  = Color(0xFF161B22);
  static const Color _blue  = Color(0xFF0078D7);
  static const Color _green = Color(0xFF238636);
  static const Color _red   = Color(0xFFDA3633);
  static const Color _dim   = Color(0xFF8B949E);

  @override
  void initState() {
    super.initState();
    IrService.hasIrBlaster().then((v) => setState(() => _hasIr = v));
  }

  Future<void> _send(AcState newState) async {
    if (_sending) return;
    setState(() { _state = newState; _sending = true; _lastMsg = 'Sending…'; });
    final ok = await IrService.sendState(newState);
    setState(() {
      _sending = false;
      _lastMsg = ok ? '✅ Signal sent!' : '❌ IR send failed';
    });
  }

  void _toggle(String key) {
    switch (key) {
      case 'power':      _send(_state.copyWith(power:      !_state.power));      break;
      case 'swingV':     _send(_state.copyWith(swingV:     !_state.swingV));     break;
      case 'swingH':     _send(_state.copyWith(swingH:     !_state.swingH));     break;
      case 'powerful':   _send(_state.copyWith(powerful:   !_state.powerful));   break;
      case 'silent':     _send(_state.copyWith(silent:     !_state.silent));     break;
      case 'economy':    _send(_state.copyWith(economy:    !_state.economy));    break;
      case 'ecoSensing': _send(_state.copyWith(ecoSensing: !_state.ecoSensing)); break;
      case 'comfort':    _send(_state.copyWith(comfort:    !_state.comfort));    break;
    }
  }

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
          border: Border.all(color: active ? _blue : const Color(0xFF30363D)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? Colors.white : _dim, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: active ? Colors.white : _dim, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _fanBtn(String label, int speed) {
    final active = _state.fanSpeed == speed;
    return GestureDetector(
      onTap: () => _send(_state.copyWith(fanSpeed: speed)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _blue : _card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? _blue : const Color(0xFF30363D)),
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.white : _dim, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _featureBtn(String label, bool active, String key, {IconData? icon}) {
    return GestureDetector(
      onTap: () => _toggle(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: active ? _blue.withOpacity(0.2) : _card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? _blue : const Color(0xFF30363D)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: active ? _blue : _dim), const SizedBox(width: 5)],
            Text(label, style: TextStyle(color: active ? _blue : _dim, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Header ──
              Row(children: [
                const Icon(Icons.ac_unit, color: Color(0xFF0078D7), size: 22),
                const SizedBox(width: 8),
                const Text('Daikin AC', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _hasIr ? _green.withOpacity(0.2) : _red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _hasIr ? _green : _red),
                  ),
                  child: Text(_hasIr ? 'IR Ready' : 'No IR', style: TextStyle(color: _hasIr ? _green : _red, fontSize: 11)),
                ),
              ]),
              const SizedBox(height: 16),

              // ── Status message ──
              if (_lastMsg.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(8)),
                  child: Text(_lastMsg, style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
                ),

              // ── Temperature card ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF30363D))),
                child: Column(children: [
                  Text(_state.power ? _state.modeLabel.toUpperCase() : 'OFF',
                    style: TextStyle(color: _state.power ? _blue : _dim, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    // Temp down
                    GestureDetector(
                      onTap: () { if (_state.temperature > 16) _send(_state.copyWith(temperature: _state.temperature - 1)); },
                      child: Container(width: 48, height: 48,
                        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF30363D))),
                        child: const Icon(Icons.remove, color: Colors.white70)),
                    ),
                    const SizedBox(width: 20),
                    Column(children: [
                      Text('${_state.temperature.toStringAsFixed(0)}°C',
                        style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w300)),
                      Text('Range: 16–30°C', style: TextStyle(color: _dim, fontSize: 10)),
                    ]),
                    const SizedBox(width: 20),
                    // Temp up
                    GestureDetector(
                      onTap: () { if (_state.temperature < 30) _send(_state.copyWith(temperature: _state.temperature + 1)); },
                      child: Container(width: 48, height: 48,
                        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF30363D))),
                        child: const Icon(Icons.add, color: Colors.white70)),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Mode buttons ──
              const Text('MODE', style: TextStyle(color: Color(0xFF8B949E), fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _modeBtn('Auto',  kModeAuto, Icons.autorenew),
                _modeBtn('Cool',  kModeCool, Icons.ac_unit),
                _modeBtn('Heat',  kModeHeat, Icons.local_fire_department),
                _modeBtn('Dry',   kModeDry,  Icons.water_drop),
                _modeBtn('Fan',   kModeFan,  Icons.wind_power),
              ]),
              const SizedBox(height: 16),

              // ── Fan speed ──
              const Text('FAN SPEED', style: TextStyle(color: Color(0xFF8B949E), fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
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

              // ── Swing ──
              const Text('SWING', style: TextStyle(color: Color(0xFF8B949E), fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _featureBtn('↕  Swing Vertical',   _state.swingV, 'swingV', icon: Icons.swap_vert)),
                const SizedBox(width: 10),
                Expanded(child: _featureBtn('↔  Swing Horizontal', _state.swingH, 'swingH', icon: Icons.swap_horiz)),
              ]),
              const SizedBox(height: 16),

              // ── Special modes grid ──
              const Text('SPECIAL MODES', style: TextStyle(color: Color(0xFF8B949E), fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 3.2,
                children: [
                  _featureBtn('⚡ POWERCHILL',  _state.powerful,   'powerful',   icon: Icons.bolt),
                  _featureBtn('🌿 ECONO',       _state.economy,    'economy',    icon: Icons.eco),
                  _featureBtn('🤫 SILENT',      _state.silent,     'silent',     icon: Icons.volume_off),
                  _featureBtn('📡 ECO SENSE',   _state.ecoSensing, 'ecoSensing', icon: Icons.sensors),
                  _featureBtn('🌊 COANDA',      _state.comfort,    'comfort',    icon: Icons.waves),
                  _featureBtn('💤 GOOD SLEEP',  _state.silent,     'silent',     icon: Icons.bedtime),
                ],
              ),
              const SizedBox(height: 24),

              // ── POWER BUTTON ──
              GestureDetector(
                onTap: () => _sending ? null : _send(_state.copyWith(power: !_state.power)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 64,
                  decoration: BoxDecoration(
                    color: _state.power ? _green : _red,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: (_state.power ? _green : _red).withOpacity(0.4), blurRadius: 16, spreadRadius: 2)],
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.power_settings_new, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Text(_state.power ? 'TURN OFF' : 'TURN ON',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              Text('Daikin ARC484B32 • IR Blaster • No Ads',
                style: TextStyle(color: _dim, fontSize: 10), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
