/// Her zaman açık ekran (AOD): siyah zeminli, OLED dostu saat, tarih, pil,
/// sonraki alarm ve kısa not. Android üçüncü taraf uygulamaların ekran
/// kapalıyken çizmesine izin vermez; bu yüzden iki dürüst yol sunulur:
/// (1) uygulama içi tam ekran: ekranı açık tutar (pil harcar), pil eşiğin
/// altına inince kendiliğinden kapanır; (2) Android'de sistem ekran
/// koruyucusu (AodDreamService): şarjda/yuvada kendiliğinden başlar.
/// iOS ve web: yalnız uygulama içi masa saati ve açıklama.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studio_core/apps/apps.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../common.dart';
import '../core.dart';
import '../ek4_core.dart';
import '../platform/native.dart';

/// Sade kadran: yalnız akrep, yelkovan ve tepe noktası.
class MinimalDialPainter extends CustomPainter {
  final DateTime now;
  final Color fg, accent;
  MinimalDialPainter(this.now, this.fg, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 * 0.92;
    void hand(double turns, double len, double w) {
      final a = turns * 2 * math.pi;
      canvas.drawLine(
        c,
        c + Offset(math.sin(a), -math.cos(a)) * r * len,
        Paint()
          ..color = fg
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round,
      );
    }

    hand((now.hour % 12 + now.minute / 60) / 12, 0.55, r * 0.05);
    hand(now.minute / 60, 0.9, r * 0.028);
    canvas.drawCircle(c, r * 0.045, Paint()..color = accent);
    canvas.drawCircle(c + Offset(0, -r), r * 0.03, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(MinimalDialPainter old) => old.now.minute != now.minute || old.fg != fg || old.accent != accent;
}

/// Pil halkası.
class BatteryRingPainter extends CustomPainter {
  final double level;
  final Color fg, accent;
  BatteryRingPainter(this.level, this.fg, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2 * 0.92;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: r);
    final w = r * 0.045;
    canvas.drawCircle(rect.center, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = fg.withValues(alpha: 0.22));
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * level.clamp(0.0, 1.0), false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = accent);
  }

  @override
  bool shouldRepaint(BatteryRingPainter old) => old.level != level || old.fg != fg || old.accent != accent;
}

/// AOD yüzü (önizleme ve tam ekran ortak).
class AodFaceView extends StatelessWidget {
  final AodPrefs p;
  final DateTime now;
  final int? battery;
  final DateTime? alarm;
  const AodFaceView({super.key, required this.p, required this.now, this.battery, this.alarm});

  @override
  Widget build(BuildContext context) {
    final pal = kPalettes[p.palette];
    final fg = Color(pal[3]);
    final accent = Color(pal[2]);
    final loc = MaterialLocalizations.of(context);
    final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final (hh, mm) = aodDigits(now, use24);
    return LayoutBuilder(builder: (context, box) {
      final u = math.min(box.maxWidth, box.maxHeight);
      final small = TextStyle(color: fg.withValues(alpha: 0.75), fontSize: math.max(12.0, u * 0.05));
      final Widget face = switch (p.face) {
        AodFace.stacked => Column(mainAxisSize: MainAxisSize.min, children: [
            Text(hh, style: TextStyle(color: fg, fontSize: u * 0.26, height: 1, fontWeight: FontWeight.w200)),
            Text(mm, style: TextStyle(color: accent, fontSize: u * 0.26, height: 1, fontWeight: FontWeight.w200)),
          ]),
        AodFace.ring => SizedBox(
            width: u * 0.55,
            height: u * 0.55,
            child: CustomPaint(
              painter: BatteryRingPainter((battery ?? 0) / 100, fg, accent),
              child: Center(
                child: FittedBox(
                  child: Text('$hh:$mm', style: TextStyle(color: fg, fontSize: u * 0.13, fontWeight: FontWeight.w200)),
                ),
              ),
            ),
          ),
        AodFace.minimal =>
          SizedBox(width: u * 0.5, height: u * 0.5, child: CustomPaint(painter: MinimalDialPainter(now, fg, accent))),
      };
      final info = [
        if (p.battery && battery != null) '%$battery',
        if (p.alarm && alarm != null) '⏰ ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(alarm!), alwaysUse24HourFormat: use24)}',
      ].join('   ');
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          face,
          SizedBox(height: u * 0.03),
          if (p.date) Text(loc.formatFullDate(now), style: small),
          if (info.isNotEmpty) Text(info, style: small),
          if (p.note.isNotEmpty)
            Text(p.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: small.copyWith(color: accent)),
        ]),
      );
    });
  }
}

class AodTool extends StatefulWidget {
  final ToolContext t;
  const AodTool(this.t, {super.key});
  @override
  State<AodTool> createState() => _AodState();
}

class _AodState extends State<AodTool> {
  ToolContext get t => widget.t;
  AodPrefs _p = const AodPrefs();
  bool _extras = false;
  DateTime _now = DateTime.now();
  DateTime? _alarm;
  Timer? _timer;
  final TextEditingController _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    () async {
      final m = await t.store.readMap('aod');
      final ex = await extrasOpen(t);
      final alarm = await KisiselNative.nextAlarm();
      if (!mounted) return;
      setState(() {
        _p = AodPrefs.fromJson(m);
        _extras = ex;
        _alarm = alarm;
        if (!_extras && _p.palette >= kFreePalettes) _p = _p.copy(palette: 0);
        _note.text = _p.note;
      });
      if (KisiselNative.android) {
        await KisiselNative.enable(NativeFeature.aod);
        await KisiselNative.setPrefs(NativeFeature.aod, _p.native());
      }
    }();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _note.dispose();
    super.dispose();
  }

  void _set(AodPrefs p) {
    setState(() => _p = p);
    t.store.writeMap('aod', p.toJson());
    if (KisiselNative.android) KisiselNative.setPrefs(NativeFeature.aod, p.native());
  }

  Future<void> _openDream() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await KisiselNative.setPrefs(NativeFeature.aod, _p.native());
    final ok = await KisiselNative.openDreamSettings(aod: true);
    if (!ok) messenger?.showSnackBar(SnackBar(content: Text(t.tx('not_available'))));
  }

  @override
  Widget build(BuildContext context) {
    final names = {AodFace.stacked: 'aod_stacked', AodFace.ring: 'aod_ring', AodFace.minimal: 'aod_minimal'};
    return ToolList(children: [
      AppPanel(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            color: Colors.black,
            height: 240,
            padding: const EdgeInsets.all(12),
            child: AodFaceView(p: _p, now: _now, battery: 80, alarm: _alarm),
          ),
        ),
      ),
      AppButton(
        label: L(t, 'aod_start'),
        icon: Icons.nightlight_round,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => _FullAod(t: t, p: _p, alarm: _alarm),
        )),
      ),
      if (KisiselNative.android)
        AppButton(label: L(t, 'aod_dream'), icon: Icons.settings_brightness_rounded, onPressed: _openDream),
      Choice<AodFace>(
        values: AodFace.values,
        labels: [for (final f in AodFace.values) L(t, names[f]!)],
        selected: _p.face,
        onChanged: (f) => _set(_p.copy(face: f)),
      ),
      AppPanel(
        child: Column(children: [
          switchRow(L(t, 'show_date'), _p.date, (b) => _set(_p.copy(date: b))),
          switchRow(L(t, 'show_battery'), _p.battery, (b) => _set(_p.copy(battery: b))),
          if (KisiselNative.android) switchRow(L(t, 'aod_alarm'), _p.alarm, (b) => _set(_p.copy(alarm: b))),
          switchRow(L(t, 'aod_shift'), _p.shift, (b) => _set(_p.copy(shift: b))),
          SliderRow(
            label: L(t, 'dim'),
            value: _p.dim * 100,
            min: 0,
            max: 80,
            divisions: 8,
            unit: '%',
            onChanged: (v) => _set(_p.copy(dim: v / 100)),
          ),
          if (!kIsWeb)
            SliderRow(
              label: L(t, 'aod_stop_below'),
              value: _p.stopBelow.toDouble(),
              min: 0,
              max: 50,
              divisions: 10,
              unit: '%',
              onChanged: (v) => _set(_p.copy(stopBelow: v.round())),
            ),
          AppTextField(
            controller: _note,
            label: L(t, 'note_text'),
            onChanged: (s) => _set(_p.copy(note: s.length > 40 ? s.substring(0, 40) : s)),
          ),
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
      AppInfoCard(L(t, KisiselNative.android ? 'aod_note_android' : 'aod_note_other'), icon: Icons.battery_alert_rounded),
    ]);
  }
}

class _FullAod extends StatefulWidget {
  final ToolContext t;
  final AodPrefs p;
  final DateTime? alarm;
  const _FullAod({required this.t, required this.p, this.alarm});
  @override
  State<_FullAod> createState() => _FullAodState();
}

class _FullAodState extends State<_FullAod> {
  DateTime _now = DateTime.now();
  Timer? _timer;
  int? _level;
  bool _charging = false;
  StreamSubscription<BatteryState>? _sub;
  final Battery _battery = Battery();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      unawaited(_readLevel());
    });
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    unawaited(WakelockPlus.enable().catchError((Object _) {}));
    if (!kIsWeb) {
      try {
        _sub = _battery.onBatteryStateChanged.listen((s) {
          final c = s == BatteryState.charging || s == BatteryState.full || s == BatteryState.connectedNotCharging;
          if (mounted) setState(() => _charging = c);
        }, onError: (Object _) {});
      } catch (_) {}
      unawaited(_readLevel());
    }
  }

  Future<void> _readLevel() async {
    if (kIsWeb) return;
    try {
      final l = await _battery.batteryLevel.timeout(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() => _level = l);
      if (aodShouldStop(l, _charging, widget.p.stopBelow)) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        Navigator.of(context).maybePop();
        messenger?.showSnackBar(SnackBar(content: Text(L(widget.t, 'aod_battery_low'))));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_sub?.cancel());
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(WakelockPlus.disable().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final off = widget.p.shift ? burnInOffset(_now.hour * 60 + _now.minute) : (0.0, 0.0);
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () => Navigator.pop(context),
        child: Stack(children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment(off.$1 * 0.4, off.$2 * 0.3 - 0.1),
              child: FractionallySizedBox(
                widthFactor: 0.8,
                heightFactor: 0.6,
                child: AodFaceView(p: widget.p, now: _now, battery: _level, alarm: widget.alarm),
              ),
            ),
          ),
          if (widget.p.dim > 0)
            Positioned.fill(child: IgnorePointer(child: ColoredBox(color: Colors.black.withValues(alpha: widget.p.dim)))),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Text(L(widget.t, 'aod_exit'),
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white24, fontSize: 13)),
          ),
        ]),
      ),
    );
  }
}
