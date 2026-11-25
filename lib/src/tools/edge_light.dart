/// Kenar ışıklandırma: ekran kenarlarında dönen, nabız gibi atan ya da
/// gökkuşağı renkli ışık. Uygulamada önizleme ve tam ekran gösterim;
/// Android'de bildirim geldiğinde (ekran açıkken) diğer uygulamaların
/// üzerinde birkaç saniye görünür. Bunun için kullanıcı iki sistem iznini
/// kendisi açar: bildirim erişimi ve "diğer uygulamaların üzerinde göster".
/// Bildirimlerin içeriği okunmaz, saklanmaz, gönderilmez.
/// iOS ve web uygulamalara bu izinleri vermez: yalnız uygulama içi gösterim.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:studio_core/apps/apps.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../common.dart';
import '../core.dart';
import '../platform/native.dart';
import '../style_core.dart';

/// Kenar ışığının renkleri: paletin vurgu renkleri ya da gökkuşağı.
List<Color> edgeColors(EdgePrefs p) {
  if (p.style == EdgeStyle.rainbow) {
    return [for (var i = 0; i <= 6; i++) HSVColor.fromAHSV(1, i * 60.0 % 360, 0.85, 1).toColor()];
  }
  final pal = kPalettes[p.palette.clamp(0, kPalettes.length - 1)];
  return [Color(pal[2]), Color(pal[3]), Color(pal[4]), Color(pal[2])];
}

class EdgePainter extends CustomPainter {
  final EdgePrefs p;
  final double time;
  final double inset;
  EdgePainter(this.p, this.time, {this.inset = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final w = p.thickness;
    final rect = Rect.fromLTWH(inset + w / 2, inset + w / 2, size.width - 2 * inset - w, size.height - 2 * inset - w);
    if (rect.width <= 0 || rect.height <= 0) return;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(p.radius));
    final colors = edgeColors(p);
    final angle = time * p.speed * math.pi;
    Shader shader;
    var opacity = 1.0;
    switch (p.style) {
      case EdgeStyle.flow:
      case EdgeStyle.rainbow:
        shader = SweepGradient(colors: colors, transform: GradientRotation(angle)).createShader(rect);
      case EdgeStyle.pulse:
        opacity = edgePulse(time, p.speed);
        shader = SweepGradient(colors: colors).createShader(rect);
      case EdgeStyle.comet:
        final c = colors.first;
        shader = SweepGradient(
          colors: [c.withValues(alpha: 0), c.withValues(alpha: 0), c.withValues(alpha: 0.6), Colors.white, c.withValues(alpha: 0)],
          stops: const [0, 0.55, 0.85, 0.97, 1],
          transform: GradientRotation(edgeCometPos(time, p.speed) * 2 * math.pi),
        ).createShader(rect);
    }
    final glow = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 2.2
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w)
      ..color = Colors.white.withValues(alpha: 0.55 * opacity);
    final line = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = Colors.white.withValues(alpha: opacity);
    canvas.drawRRect(rr, glow);
    canvas.drawRRect(rr, line);
  }

  @override
  bool shouldRepaint(EdgePainter old) => old.time != time || old.p != p;
}

/// Zamanla yeniden çizilen kenar ışığı.
class EdgeGlow extends StatefulWidget {
  final EdgePrefs prefs;
  final Widget? child;
  const EdgeGlow({super.key, required this.prefs, this.child});
  @override
  State<EdgeGlow> createState() => _EdgeGlowState();
}

class _EdgeGlowState extends State<EdgeGlow> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => setState(() => _t = d.inMicroseconds / 1e6))..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(foregroundPainter: EdgePainter(widget.prefs, _t), child: widget.child ?? const SizedBox.expand());
}

class EdgeLightTool extends StatefulWidget {
  final ToolContext t;
  const EdgeLightTool(this.t, {super.key});
  @override
  State<EdgeLightTool> createState() => _EdgeLightState();
}

class _EdgeLightState extends State<EdgeLightTool> with WidgetsBindingObserver {
  ToolContext get t => widget.t;
  EdgePrefs _p = const EdgePrefs();
  bool _extras = false;
  bool _listener = false, _overlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    () async {
      final m = await t.store.readMap('edge');
      final ex = await extrasOpen(t);
      if (!mounted) return;
      setState(() {
        _p = EdgePrefs.fromJson(m);
        _extras = ex;
        if (!_extras && _p.palette >= kFreePalettes) _p = _p.copy(palette: 0);
      });
      if (KisiselNative.android) {
        await KisiselNative.enable(NativeFeature.edge);
        await _refresh();
        await KisiselNative.setEdge(_native(_p));
      }
    }();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Kullanıcı sistem ayarlarından dönünce izinleri yeniden okur.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && KisiselNative.android) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final s = await KisiselNative.edgeStatus();
    if (!mounted) return;
    setState(() {
      _listener = s.listener;
      _overlay = s.overlay;
      if (_p.enabled && !(s.listener && s.overlay)) _p = _p.copy(enabled: false);
    });
  }

  /// Android servisine giden ayarlar: paletin vurgu renkleriyle.
  Map<String, Object?> _native(EdgePrefs p) {
    final pal = kPalettes[p.palette.clamp(0, kPalettes.length - 1)];
    return {...p.toJson(), 'colors': [pal[2], pal[3], pal[4]]};
  }

  void _set(EdgePrefs p) {
    setState(() => _p = p);
    t.store.writeMap('edge', p.toJson());
    if (KisiselNative.android) KisiselNative.setEdge(_native(p));
  }

  Widget _slider(String label, double v, double min, double max, String unit, ValueChanged<double> on) => Row(children: [
        Expanded(child: Text(label)),
        Expanded(flex: 2, child: Slider(value: v.clamp(min, max).toDouble(), min: min, max: max, onChanged: on)),
        SizedBox(width: 48, child: Text('${v.round()}$unit', textAlign: TextAlign.end)),
      ]);

  Widget _permRow(String label, bool ok, Future<bool> Function() open) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: ok ? Colors.greenAccent : Colors.white54),
        title: Text(label),
        trailing: ok
            ? null
            : TextButton(
                onPressed: () async {
                  if (!await open() && mounted) {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(t.tx('not_available'))));
                  }
                },
                child: Text(L(t, 'allow')),
              ),
      );

  @override
  Widget build(BuildContext context) {
    final names = {EdgeStyle.flow: 'e_flow', EdgeStyle.pulse: 'e_pulse', EdgeStyle.rainbow: 'e_rainbow', EdgeStyle.comet: 'e_comet'};
    return ToolList(children: [
      AppPanel(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            color: Colors.black,
            height: 260,
            child: EdgeGlow(
              prefs: _p,
              child: Center(child: Icon(Icons.notifications_active_rounded, size: 56, color: Colors.white.withValues(alpha: 0.6))),
            ),
          ),
        ),
      ),
      AppButton(
        label: L(t, 'fullscreen'),
        icon: Icons.fullscreen_rounded,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => _FullEdge(p: _p),
        )),
      ),
      Choice<EdgeStyle>(
        values: EdgeStyle.values,
        labels: [for (final s in EdgeStyle.values) L(t, names[s]!)],
        selected: _p.style,
        onChanged: (s) => _set(_p.copy(style: s)),
      ),
      AppPanel(
        child: Column(children: [
          _slider(L(t, 'thickness'), _p.thickness, 2, 16, '', (v) => _set(_p.copy(thickness: v))),
          _slider(L(t, 'corner'), _p.radius, 0, 60, '', (v) => _set(_p.copy(radius: v))),
          _slider(L(t, 'speed'), _p.speed * 10, 3, 30, '', (v) => _set(_p.copy(speed: v / 10))),
          _slider(L(t, 'duration'), _p.seconds, 2, 15, ' s', (v) => _set(_p.copy(seconds: v.roundToDouble()))),
          const SizedBox(height: 8),
          if (_p.style != EdgeStyle.rainbow)
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
      if (KisiselNative.android) ...[
        AppHeading(L(t, 'on_notifications'), icon: Icons.notifications_rounded),
        AppPanel(
          child: Column(children: [
            _permRow(L(t, 'notif_access'), _listener, KisiselNative.openNotificationAccess),
            _permRow(L(t, 'overlay_perm'), _overlay, KisiselNative.openOverlaySettings),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(L(t, 'edge_enable')),
              value: _p.enabled,
              onChanged: (_listener && _overlay) ? (b) => _set(_p.copy(enabled: b)) : null,
            ),
            if (_overlay)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  icon: const Icon(Icons.bolt_rounded),
                  label: Text(L(t, 'test_now')),
                  onPressed: () async {
                    await KisiselNative.setEdge(_native(_p));
                    await KisiselNative.testEdge();
                  },
                ),
              ),
          ]),
        ),
        AppInfoCard(L(t, 'edge_note_android'), icon: Icons.privacy_tip_outlined),
      ] else
        AppInfoCard(L(t, 'edge_note_other'), icon: Icons.info_outline_rounded),
    ]);
  }
}

class _FullEdge extends StatefulWidget {
  final EdgePrefs p;
  const _FullEdge({required this.p});
  @override
  State<_FullEdge> createState() => _FullEdgeState();
}

class _FullEdgeState extends State<_FullEdge> {
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

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.pop(context),
          child: EdgeGlow(prefs: widget.p),
        ),
      );
}
