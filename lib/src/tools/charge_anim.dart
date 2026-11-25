/// Şarj animasyonu: pil düzeyini gösteren tam ekran animasyon (sıvı,
/// halka, kabarcıklar, çubuklar). Uygulamada şarjdayken açılır ve ekranı
/// açık tutar. Android'de aynı animasyon sistem ekran koruyucusu olarak
/// seçilebilir ("Şarj olurken başlat"): ChargeDreamService (android/).
/// Uygulama kilit ekranını ya da sistem şarj ekranını DEĞİŞTİRMEZ.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:studio_core/apps/apps.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../common.dart';
import '../core.dart';
import '../platform/native.dart';
import '../style_core.dart';

class ChargePainter extends CustomPainter {
  final ChargePrefs p;
  final double level; // 0–1
  final double time;
  final bool charging;
  ChargePainter(this.p, this.level, this.time, this.charging);

  @override
  void paint(Canvas canvas, Size size) {
    final pal = kPalettes[p.palette.clamp(0, kPalettes.length - 1)];
    final a = Color(pal[2]), b = Color(pal[3]), c = Color(pal[4]);
    final w = size.width, h = size.height;
    // Şarj olmuyorsa animasyon yavaşlar.
    final t = charging ? time : time * 0.25;
    switch (p.style) {
      case ChargeStyle.liquid:
        for (var layer = 0; layer < 2; layer++) {
          final path = Path()..moveTo(0, h);
          for (var i = 0; i <= 48; i++) {
            final x = i / 48;
            final y = liquidSurface(level, x + layer * 0.37, t * (layer == 0 ? 1 : 1.4));
            path.lineTo(x * w, h - y * h);
          }
          path
            ..lineTo(w, h)
            ..close();
          canvas.drawPath(
            path,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: layer == 0 ? [b, a] : [a.withValues(alpha: 0.5), c.withValues(alpha: 0.4)],
              ).createShader(Offset.zero & size),
          );
        }
      case ChargeStyle.ring:
        final center = size.center(Offset.zero);
        final r = math.min(w, h) * 0.36;
        final sw = r * 0.12;
        canvas.drawCircle(center, r, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..color = Colors.white.withValues(alpha: 0.08));
        final rect = Rect.fromCircle(center: center, radius: r);
        final arc = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(colors: [a, b, c, a], transform: GradientRotation(t * 0.8)).createShader(rect);
        canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * level.clamp(0.01, 1.0), false, arc);
        canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * level.clamp(0.01, 1.0), false,
            arc..maskFilter = MaskFilter.blur(BlurStyle.normal, sw * 0.8));
        // Halkanın çevresinde dönen ışık noktası.
        final ang = -math.pi / 2 + t * 1.6;
        canvas.drawCircle(center + Offset(math.cos(ang), math.sin(ang)) * (r + sw * 1.4), sw * 0.25,
            Paint()..color = c.withValues(alpha: 0.8));
      case ChargeStyle.bubbles:
        final fillH = h * level.clamp(0.0, 1.0);
        canvas.drawRect(
          Rect.fromLTWH(0, h - fillH, w, fillH),
          Paint()
            ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [a.withValues(alpha: 0.45), b.withValues(alpha: 0.2)])
                .createShader(Rect.fromLTWH(0, h - fillH, w, fillH)),
        );
        final count = 14 + (level * 26).round();
        for (var i = 0; i < count; i++) {
          final (x, y, rad) = bubbleAt(i, t);
          final pos = Offset(x * w, h - (1 - y) * fillH);
          if (pos.dy < h - fillH) continue;
          canvas.drawCircle(pos, rad * math.min(w, h), Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = (i.isEven ? b : c).withValues(alpha: 0.8));
        }
      case ChargeStyle.bars:
        const nb = 16;
        final bw = w / (nb * 1.6);
        for (var i = 0; i < nb; i++) {
          final wave = 0.5 + 0.5 * math.sin(t * 3 + i * 0.6);
          final bh = h * (0.08 + level * 0.7 * (0.6 + 0.4 * wave));
          final bx = (i + 0.3) * w / nb;
          final bar = RRect.fromRectAndRadius(Rect.fromLTWH(bx, h * 0.9 - bh, bw, bh), Radius.circular(bw / 2));
          canvas.drawRRect(bar, Paint()..shader = LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [a, c]).createShader(bar.outerRect));
        }
    }
  }

  @override
  bool shouldRepaint(ChargePainter old) => old.time != time || old.level != level || old.p != p || old.charging != charging;
}

/// Pil düzeyi ve şarj durumunu izleyen animasyon gövdesi.
class ChargeView extends StatefulWidget {
  final ToolContext t;
  final ChargePrefs p;
  final bool full;
  final VoidCallback? onUnplug;
  const ChargeView({super.key, required this.t, required this.p, this.full = false, this.onUnplug});
  @override
  State<ChargeView> createState() => _ChargeViewState();
}

class _ChargeViewState extends State<ChargeView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final Battery _battery = Battery();
  StreamSubscription<BatteryState>? _sub;
  Timer? _poll;
  double _t = 0;
  int? _level;
  bool _charging = false;
  bool _seenCharging = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => setState(() => _t = d.inMicroseconds / 1e6))..start();
    if (!kIsWeb) {
      try {
        _sub = _battery.onBatteryStateChanged.listen((s) {
          final c = s == BatteryState.charging || s == BatteryState.full || s == BatteryState.connectedNotCharging;
          if (!mounted) return;
          setState(() => _charging = c);
          if (c) _seenCharging = true;
          if (!c && _seenCharging) widget.onUnplug?.call();
          unawaited(_read());
        }, onError: (Object _) {});
      } catch (_) {}
    }
    unawaited(_read());
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _read());
  }

  Future<void> _read() async {
    try {
      final l = await _battery.batteryLevel.timeout(const Duration(seconds: 2));
      if (mounted) setState(() => _level = l);
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker.dispose();
    _poll?.cancel();
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    // Pil okunamıyorsa (web, masaüstü) gösterim için döngüsel bir düzey.
    final shown = _level ?? (60 + 30 * math.sin(_t * 0.2)).round();
    final level = shown / 100;
    final loc = MaterialLocalizations.of(context);
    final now = DateTime.now();
    final status = _level == null
        ? ''
        : (shown >= 100 ? L(t, 'battery_full') : (_charging ? L(t, 'charging') : L(t, 'not_charging')));
    return LayoutBuilder(builder: (context, box) {
      final u = math.min(box.maxWidth, box.maxHeight);
      return Stack(children: [
        Positioned.fill(child: CustomPaint(painter: ChargePainter(widget.p, level, _t, _charging || _level == null))),
        Positioned.fill(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (widget.p.clock)
              Text(
                loc.formatTimeOfDay(TimeOfDay.fromDateTime(now), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context)),
                style: TextStyle(color: Colors.white70, fontSize: u * (widget.full ? 0.09 : 0.08), fontWeight: FontWeight.w300),
              ),
            if (widget.p.percent)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_charging ? Icons.bolt_rounded : Icons.battery_std_rounded, color: Colors.white, size: u * 0.1),
                Text('%$shown', style: TextStyle(color: Colors.white, fontSize: u * 0.16, fontWeight: FontWeight.w800)),
              ]),
            if (status.isNotEmpty) Text(status, style: TextStyle(color: Colors.white60, fontSize: math.max(13.0, u * 0.04))),
          ]),
        ),
      ]);
    });
  }
}

class ChargeAnimTool extends StatefulWidget {
  final ToolContext t;
  const ChargeAnimTool(this.t, {super.key});
  @override
  State<ChargeAnimTool> createState() => _ChargeAnimState();
}

class _ChargeAnimState extends State<ChargeAnimTool> {
  ToolContext get t => widget.t;
  ChargePrefs _p = const ChargePrefs();
  bool _extras = false;

  @override
  void initState() {
    super.initState();
    () async {
      final m = await t.store.readMap('charge');
      final ex = await extrasOpen(t);
      if (!mounted) return;
      setState(() {
        _p = ChargePrefs.fromJson(m);
        _extras = ex;
        if (!_extras && _p.palette >= kFreePalettes) _p = _p.copy(palette: 0);
      });
      if (KisiselNative.android) {
        await KisiselNative.enable(NativeFeature.chargeDream);
        await _push();
      }
    }();
  }

  Future<void> _push() {
    final pal = kPalettes[_p.palette];
    return KisiselNative.setCharge({..._p.toJson(), 'colors': [pal[2], pal[3], pal[4]]});
  }

  void _set(ChargePrefs p) {
    setState(() => _p = p);
    t.store.writeMap('charge', p.toJson());
    if (KisiselNative.android) _push();
  }

  Future<void> _openDream() async {
    await _push();
    await KisiselNative.enable(NativeFeature.chargeDream);
    final ok = await KisiselNative.openDreamSettings(charge: true);
    if (!ok && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(t.tx('not_available'))));
    }
  }

  Widget _switch(String label, bool v, ValueChanged<bool> on) =>
      SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(label), value: v, onChanged: on);

  @override
  Widget build(BuildContext context) {
    final names = {ChargeStyle.liquid: 'c_liquid', ChargeStyle.ring: 'c_ring', ChargeStyle.bubbles: 'c_bubbles', ChargeStyle.bars: 'c_bars'};
    return ToolList(children: [
      AppPanel(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(color: Colors.black, height: 280, child: ChargeView(t: t, p: _p)),
        ),
      ),
      AppButton(
        label: L(t, 'start_anim'),
        icon: Icons.battery_charging_full_rounded,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => _FullCharge(t: t, p: _p),
        )),
      ),
      if (KisiselNative.android)
        AppButton(label: L(t, 'screensaver_settings'), icon: Icons.settings_brightness_rounded, onPressed: _openDream),
      Choice<ChargeStyle>(
        values: ChargeStyle.values,
        labels: [for (final s in ChargeStyle.values) L(t, names[s]!)],
        selected: _p.style,
        onChanged: (s) => _set(_p.copy(style: s)),
      ),
      AppPanel(
        child: Column(children: [
          _switch(L(t, 'show_battery'), _p.percent, (b) => _set(_p.copy(percent: b))),
          _switch(L(t, 'show_time'), _p.clock, (b) => _set(_p.copy(clock: b))),
          _switch(L(t, 'close_unplug'), _p.closeOnUnplug, (b) => _set(_p.copy(closeOnUnplug: b))),
          const SizedBox(height: 8),
          PaletteRow(
            palettes: kPalettes,
            selected: _p.palette,
            free: kFreePalettes,
            unlocked: _extras,
            onChanged: (i) => _set(_p.copy(palette: i)),
          ),
        ]),
      ),
      if (!_extras) UnlockButton(t: t, onUnlocked: () => setState(() => _extras = true)),
      AppInfoCard(L(t, KisiselNative.android ? 'charge_note_android' : 'charge_note_other'), icon: Icons.info_outline_rounded),
    ]);
  }
}

class _FullCharge extends StatefulWidget {
  final ToolContext t;
  final ChargePrefs p;
  const _FullCharge({required this.t, required this.p});
  @override
  State<_FullCharge> createState() => _FullChargeState();
}

class _FullChargeState extends State<_FullCharge> {
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    unawaited(WakelockPlus.enable().catchError((Object _) {}));
  }

  @override
  void dispose() {
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(WakelockPlus.disable().catchError((Object _) {}));
    super.dispose();
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _close,
          child: ChargeView(t: widget.t, p: widget.p, full: true, onUnplug: widget.p.closeOnUnplug ? _close : null),
        ),
      );
}
