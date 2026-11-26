/// Gelen aramada flaş (Android): telefon çalarken fener ve isteğe bağlı
/// ekran kenarı ritimle yanıp söner. En az yetki: arama, sistemin gelen
/// arama bildiriminden anlaşılır (CallFlashService); READ_PHONE_STATE,
/// arama kaydı, kişiler ya da kamera izni İSTENMEZ, arayan okunmaz. Fener
/// kamera açılmadan yakılır. Kullanıcı bildirim erişimini kendisi açar.
/// iOS'ta uygulamalar aramayı algılayamaz: iOS'un "Uyarılar için LED Flaşı"
/// ayarı anlatılır; uygulama içinde ekran flaşı önizlenir.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:studio_core/apps/apps.dart';

import '../common.dart';
import '../core.dart';
import '../ek4_core.dart';
import '../platform/native.dart';

/// Ekran flaşı önizlemesi: çerçeve ritimle yanar.
class FlashPreview extends StatefulWidget {
  final CallFlashPrefs p;
  final bool running;
  const FlashPreview({super.key, required this.p, required this.running});
  @override
  State<FlashPreview> createState() => _FlashPreviewState();
}

class _FlashPreviewState extends State<FlashPreview> {
  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  bool _on = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(FlashPreview old) {
    super.didUpdateWidget(old);
    if (old.running != widget.running) _sync();
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    _clock
      ..reset()
      ..stop();
    if (widget.running) {
      _clock.start();
      _timer = Timer.periodic(const Duration(milliseconds: 20), (_) {
        final on = flashOnAt(flashCycle(widget.p.pattern, widget.p.speed), _clock.elapsedMilliseconds);
        if (on != _on && mounted) setState(() => _on = on);
      });
    } else if (_on) {
      setState(() => _on = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(kPalettes[widget.p.palette][4]);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 40),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _on ? color : Colors.white12, width: _on ? 8 : 2),
        boxShadow: _on ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 24, spreadRadius: 2)] : const [],
      ),
      child: Center(
        child: Icon(
          _on ? Icons.flashlight_on_rounded : Icons.ring_volume_rounded,
          size: 64,
          color: _on ? Colors.white : Colors.white54,
        ),
      ),
    );
  }
}

class CallFlashTool extends StatefulWidget {
  final ToolContext t;
  const CallFlashTool(this.t, {super.key});
  @override
  State<CallFlashTool> createState() => _CallFlashState();
}

class _CallFlashState extends State<CallFlashTool> with WidgetsBindingObserver {
  ToolContext get t => widget.t;
  CallFlashPrefs _p = const CallFlashPrefs();
  bool _extras = false, _listener = false, _overlay = false, _torch = true, _preview = false;
  Timer? _stopPreview;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    () async {
      final m = await t.store.readMap('call_flash');
      final ex = await extrasOpen(t);
      if (!mounted) return;
      setState(() {
        _p = CallFlashPrefs.fromJson(m);
        _extras = ex;
        if (!_extras && _p.palette >= kFreePalettes) _p = _p.copy(palette: 0);
      });
      if (KisiselNative.android) {
        await KisiselNative.enable(NativeFeature.call);
        await _refresh();
        await KisiselNative.setPrefs(NativeFeature.call, _p.native());
      }
    }();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPreview?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && KisiselNative.android) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final s = await KisiselNative.featureStatus(NativeFeature.call);
    if (!mounted) return;
    setState(() {
      _listener = s.listener;
      _overlay = s.overlay;
      _torch = s.torch;
    });
    if (_p.enabled && !s.listener) _set(_p.copy(enabled: false));
  }

  void _set(CallFlashPrefs p) {
    setState(() => _p = p);
    t.store.writeMap('call_flash', p.toJson());
    if (KisiselNative.android) KisiselNative.setPrefs(NativeFeature.call, p.native());
  }

  void _runPreview() {
    _stopPreview?.cancel();
    setState(() => _preview = true);
    _stopPreview = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _preview = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final names = {FlashPattern.steady: 'cf_steady', FlashPattern.heart: 'cf_heart', FlashPattern.fast: 'cf_fast'};
    return ToolList(children: [
      AppPanel(
        padding: EdgeInsets.zero,
        child: SizedBox(height: 200, child: FlashPreview(p: _p, running: _preview)),
      ),
      AppButton(label: L(t, 'cf_preview'), icon: Icons.play_arrow_rounded, onPressed: _runPreview),
      Choice<FlashPattern>(
        values: FlashPattern.values,
        labels: [for (final f in FlashPattern.values) L(t, names[f]!)],
        selected: _p.pattern,
        onChanged: (f) => _set(_p.copy(pattern: f)),
      ),
      if (KisiselNative.android) ...[
        AppHeading(L(t, 'cf_enable'), icon: Icons.call_rounded),
        if (!_torch) AppInfoCard(L(t, 'cf_no_flash'), icon: Icons.flashlight_off_rounded),
        AppPanel(
          child: Column(children: [
            PermRow(t: t, label: L(t, 'notif_access'), ok: _listener, open: () => KisiselNative.openListenerAccess(NativeFeature.call)),
            switchRow(L(t, 'cf_enable'), _p.enabled, _listener ? (b) => _set(_p.copy(enabled: b)) : null),
            switchRow(L(t, 'cf_screen'), _p.screen, (b) => _set(_p.copy(screen: b))),
            if (_p.screen) PermRow(t: t, label: L(t, 'overlay_perm'), ok: _overlay, open: KisiselNative.openOverlaySettings),
            switchRow(L(t, 'cf_skip_silent'), _p.skipSilent, (b) => _set(_p.copy(skipSilent: b))),
            SliderRow(
              label: L(t, 'cf_battery'),
              value: _p.minBattery.toDouble(),
              min: 0,
              max: 50,
              divisions: 10,
              unit: '%',
              onChanged: (v) => _set(_p.copy(minBattery: v.round())),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: const Icon(Icons.bolt_rounded),
                label: Text(L(t, 'test_now')),
                onPressed: () async {
                  await KisiselNative.setPrefs(NativeFeature.call, _p.native());
                  await KisiselNative.testFlash(3);
                },
              ),
            ),
          ]),
        ),
      ],
      AppPanel(
        child: Column(children: [
          SliderRow(
            label: L(t, 'speed'),
            value: _p.speed * 10,
            min: 5,
            max: 20,
            divisions: 15,
            onChanged: (v) => _set(_p.copy(speed: v / 10)),
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
      AppInfoCard(L(t, KisiselNative.android ? 'cf_note_android' : 'cf_note_other'), icon: Icons.privacy_tip_outlined),
    ]);
  }
}
