import 'dart:async';
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

  // ── State ─────────────────────────────────────────────────────────────
  AcState _ac        = AcState();
  bool    _hasIr     = false;
  bool    _busy      = false;   // sending in progress
  bool    _holding   = false;   // finger held on power btn
  int     _holdFires = 0;       // how many hold signals sent

  // ── Hold-press internals ──────────────────────────────────────────────
  Timer?  _holdTimer;
  Timer?  _tapOrHoldTimer;      // 500 ms disambiguator
  bool    _decidedLong = false;

  // ── Colours ───────────────────────────────────────────────────────────
  static const _bg     = Color(0xFF0D1117);
  static const _card   = Color(0xFF161B22);
  static const _blue   = Color(0xFF0078D7);
  static const _green  = Color(0xFF238636);
  static const _red    = Color(0xFFDA3633);
  static const _amber  = Color(0xFFD29922);
  static const _dim    = Color(0xFF8B949E);
  static const _bdr    = Color(0xFF30363D);

  @override
  void initState() {
    super.initState();
    IrService.hasIrBlaster().then((v) => setState(() => _hasIr = v));
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _tapOrHoldTimer?.cancel();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════
  // IR sending helpers
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _sendOnce(AcState s) async {
    if (_busy) return;
    setState(() { _ac = s; _busy = true; });
    final err = await IrService.sendOnce(s);
    if (!mounted) return;
    setState(() => _busy = false);
    err == null ? _snack('✅ Sent') : _errorDialog(err);
  }

  // Power TAP: 8 sequential signals, 200 ms apart (simulates remote hold)
  Future<void> _powerTap() async {
    if (_busy || _holding) return;
    final next = _ac.copyWith(power: !_ac.power);
    setState(() { _ac = next; _busy = true; });
    _snack(next.power
        ? 'Turning ON  —  sending 8 signals…'
        : 'Turning OFF  —  sending 8 signals…');
    final err = await IrService.sendRepeat(next, count: 8, gapMs: 200);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) _errorDialog(err);
    else _snack(next.power ? '✅ AC ON signals sent!' : '✅ AC OFF signals sent!',
        bg: _green);
  }

  // ── Raw pointer callbacks for power button ────────────────────────────
  void _onPowerDown() {
    if (_busy) return;
    _decidedLong = false;
    // After 500 ms without releasing → treat as long-press
    _tapOrHoldTimer = Timer(const Duration(milliseconds: 500), () {
      _decidedLong = true;
      _startHold();
    });
  }

  void _onPowerUp() {
    _tapOrHoldTimer?.cancel();
    if (_decidedLong) {
      _stopHold();
    } else {
      _powerTap();   // quick tap
    }
  }

  void _startHold() {
    if (_busy) return;
    final target = _ac.copyWith(power: !_ac.power);
    setState(() { _ac = target; _holding = true; _holdFires = 0; });
    _fireHold(target);
    _holdTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (!_holding || !mounted) return;
      setState(() => _holdFires++);
      _fireHold(target);
    });
  }

  Future<void> _fireHold(AcState s) async {
    await IrService.sendOnce(s);   // single signal per tick
  }

  void _stopHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (!mounted) return;
    final count = _holdFires + 1;
    setState(() { _holding = false; _holdFires = 0; });
    _snack('✅ Hold released — sent ' + count.toString() + ' signals', bg: _green);
  }

  // ══════════════════════════════════════════════════════════════════════
  // Feedback
  // ══════════════════════════════════════════════════════════════════════

  void _snack(String msg, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: bg ?? _blue,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  void _errorDialog(String msg) {
    if (!mounted) return;
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [
        Icon(Icons.error_outline, color: Color(0xFFDA3633)),
        SizedBox(width: 8),
        Text('IR Error', style: TextStyle(color: Colors.white, fontSize: 16)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8)),
          child: Text(msg, style: const TextStyle(color: Colors.orange, fontSize: 12))),
        const SizedBox(height: 12),
        const Text('• Point TOP EDGE of phone at AC (IR blaster is there)\n'
                   '• Distance: 30–80 cm, clear line of sight\n'
                   '• Settings → Apps → Daikin AC → Permissions → grant all',
            style: TextStyle(color: Color(0xFF8B949E), fontSize: 12, height: 1.7)),
      ]),
      actions: [TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK', style: TextStyle(color: Color(0xFF0078D7))))],
    ));
  }

  // ══════════════════════════════════════════════════════════════════════
  // Widget builders
  // ══════════════════════════════════════════════════════════════════════

  Widget _modeBtn(String label, int mode, IconData icon) {
    final on = _ac.mode == mode && _ac.power;
    return GestureDetector(
      onTap: () => _sendOnce(_ac.copyWith(mode: mode, power: true)),
      child: AnimatedContainer(duration: const Duration(milliseconds: 180),
        width: 58, height: 62,
        decoration: BoxDecoration(
          color: on ? _blue : _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? _blue : _bdr)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: on ? Colors.white : _dim, size: 20),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
              color: on ? Colors.white : _dim, fontSize: 10, fontWeight: FontWeight.w600)),
        ])),
    );
  }

  Widget _fanBtn(String label, int speed) {
    final on = _ac.fanSpeed == speed;
    return GestureDetector(
      onTap: () => _sendOnce(_ac.copyWith(fanSpeed: speed)),
      child: AnimatedContainer(duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: on ? _blue : _card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: on ? _blue : _bdr)),
        child: Text(label, style: TextStyle(
            color: on ? Colors.white : _dim, fontSize: 11, fontWeight: FontWeight.w600))),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 180),
        height: 50,
        decoration: BoxDecoration(
          color: on ? _blue.withAlpha(45) : _card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? _blue : _bdr)),
        child: Center(child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(color: on ? _blue : _dim,
                fontSize: 11, fontWeight: FontWeight.w600)))),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(
        color: Color(0xFF8B949E), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w600)),
  );

  // ══════════════════════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(child: Stack(children: [

        // ── Scrollable content ──────────────────────────────────────────
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // Header row
            Row(children: [
              const Icon(Icons.ac_unit, color: Color(0xFF0078D7), size: 22),
              const SizedBox(width: 8),
              const Text('Daikin AC', style: TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              // IR test badge
              GestureDetector(
                onTap: _irTest,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: _hasIr ? _green.withAlpha(35) : _red.withAlpha(35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _hasIr ? _green : _red)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.sensors, size: 12, color: _hasIr ? _green : _red),
                    const SizedBox(width: 4),
                    Text(_hasIr ? 'IR ✓  Test' : 'Test IR',
                        style: TextStyle(color: _hasIr ? _green : _red, fontSize: 11)),
                  ])),
              ),
            ]),
            const SizedBox(height: 10),

            // Hint banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: _amber.withAlpha(18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _amber.withAlpha(100))),
              child: const Row(children: [
                Icon(Icons.touch_app, color: Color(0xFFD29922), size: 15),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'TAP power button once  (8 signals auto-sent)  '
                  'OR  press & HOLD  for continuous IR fire',
                  style: TextStyle(color: Color(0xFFD29922), fontSize: 11))),
              ]),
            ),
            const SizedBox(height: 14),

            // ── Temperature card ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: _card, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _bdr)),
              child: Column(children: [
                AnimatedSwitcher(duration: const Duration(milliseconds: 300),
                  child: Text(
                    _ac.power ? _ac.modeLabel.toUpperCase() : 'STANDBY',
                    key: ValueKey(_ac.power.toString() + _ac.modeLabel),
                    style: TextStyle(color: _ac.power ? _blue : _dim,
                        fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2))),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _tempBtn(Icons.remove, () {
                    if (_ac.temperature > 16)
                      _sendOnce(_ac.copyWith(temperature: _ac.temperature - 1, power: true));
                  }),
                  const SizedBox(width: 18),
                  Column(children: [
                    AnimatedSwitcher(duration: const Duration(milliseconds: 200),
                      child: Text(
                        _ac.temperature.toStringAsFixed(0) + '°C',
                        key: ValueKey(_ac.temperature),
                        style: const TextStyle(color: Colors.white, fontSize: 54,
                            fontWeight: FontWeight.w200))),
                    Text('Fan: ' + _ac.fanLabel,
                        style: TextStyle(color: _dim, fontSize: 11)),
                  ]),
                  const SizedBox(width: 18),
                  _tempBtn(Icons.add, () {
                    if (_ac.temperature < 30)
                      _sendOnce(_ac.copyWith(temperature: _ac.temperature + 1, power: true));
                  }),
                ]),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Mode ─────────────────────────────────────────────────
            _section('MODE'),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _modeBtn('Auto', kModeAuto, Icons.autorenew),
              _modeBtn('Cool', kModeCool, Icons.ac_unit),
              _modeBtn('Heat', kModeHeat, Icons.local_fire_department),
              _modeBtn('Dry',  kModeDry,  Icons.water_drop),
              _modeBtn('Fan',  kModeFan,  Icons.wind_power),
            ]),
            const SizedBox(height: 16),

            // ── Fan speed ─────────────────────────────────────────────
            _section('FAN SPEED'),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _fanBtn('Auto', kFanAuto),
              _fanBtn('1', 3), _fanBtn('2', 4), _fanBtn('3', 5),
              _fanBtn('4', 6), _fanBtn('5', 7),
              _fanBtn('SIL', kFanSilent),
            ]),
            const SizedBox(height: 16),

            // ── Swing ─────────────────────────────────────────────────
            _section('SWING'),
            Row(children: [
              Expanded(child: _chip('↕  Swing V', _ac.swingV,
                  () => _sendOnce(_ac.copyWith(swingV: !_ac.swingV)))),
              const SizedBox(width: 10),
              Expanded(child: _chip('↔  Swing H', _ac.swingH,
                  () => _sendOnce(_ac.copyWith(swingH: !_ac.swingH)))),
            ]),
            const SizedBox(height: 16),

            // ── Special modes ─────────────────────────────────────────
            _section('SPECIAL MODES'),
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 3.2,
              children: [
                _chip('⚡ POWERCHILL', _ac.powerful,
                    () => _sendOnce(_ac.copyWith(powerful: !_ac.powerful))),
                _chip('🌿 ECONO',      _ac.economy,
                    () => _sendOnce(_ac.copyWith(economy: !_ac.economy))),
                _chip('🤫 SILENT',     _ac.silent,
                    () => _sendOnce(_ac.copyWith(silent: !_ac.silent))),
                _chip('📡 ECO SENSE',  _ac.ecoSensing,
                    () => _sendOnce(_ac.copyWith(ecoSensing: !_ac.ecoSensing))),
                _chip('🌊 COANDA',     _ac.comfort,
                    () => _sendOnce(_ac.copyWith(comfort: !_ac.comfort))),
                _chip('💤 GOOD SLEEP', _ac.silent,
                    () => _sendOnce(_ac.copyWith(silent: !_ac.silent))),
              ]),
          ]),
        ),

        // ── Floating POWER button (Listener for reliable tap + hold) ───
        Positioned(
          bottom: 16, left: 16, right: 16,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _onPowerDown(),
            onPointerUp:   (_) => _onPowerUp(),
            onPointerCancel: (_) => _onPowerUp(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 70,
              decoration: BoxDecoration(
                color: _holding ? _amber
                    : _busy    ? _blue.withAlpha(200)
                    : _ac.power ? _green : _red,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(
                  color: (_holding ? _amber : _ac.power ? _green : _red).withAlpha(100),
                  blurRadius: 20, spreadRadius: 1)]),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (_busy || _holding)
                  const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                else
                  const Icon(Icons.power_settings_new, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(
                    _holding
                        ? 'HOLDING… (' + (_holdFires + 1).toString() + '× sent)'
                        : _busy
                            ? 'SENDING 8 SIGNALS…'
                            : _ac.power ? 'TURN OFF' : 'TURN ON',
                    style: const TextStyle(color: Colors.white, fontSize: 17,
                        fontWeight: FontWeight.bold, letterSpacing: 1)),
                  Text(
                    _holding ? 'Release to stop'
                        : _busy ? 'Please wait…'
                        : 'TAP once  |  HOLD for continuous',
                    style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 10)),
                ]),
              ]),
            ),
          ),
        ),
      ])),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // Misc helpers
  // ══════════════════════════════════════════════════════════════════════

  Widget _tempBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(width: 52, height: 52,
      decoration: BoxDecoration(color: _bg,
          borderRadius: BorderRadius.circular(14), border: Border.all(color: _bdr)),
      child: Icon(icon, color: Colors.white70, size: 26)),
  );

  Future<void> _irTest() async {
    // NEC test pulse — just verifies the hardware fires
    const testPattern = [
      9000,4500,560,560,560,1690,560,560,560,560,560,560,560,560,560,560,
      560,560,560,1690,560,1690,560,1690,560,1690,560,1690,560,1690,560,1690,
      560,560,560,1690,560,560,560,560,560,560,560,560,560,560,560,560,
      560,1690,560,560,560,1690,560,1690,560,1690,560,1690,560,1690,560,1690,560,1690,560,
    ];
    try {
      await const MethodChannel('com.daikin.accontroller/ir')
          .invokeMethod('transmit', {'frequency': 38000, 'pattern': testPattern});
      _snack('IR test pulse sent ✅', bg: _green);
    } on PlatformException catch (e) {
      _snack('IR test FAILED: ' + (e.message ?? e.code), bg: _red);
    }
  }
}
