/// Dinamik bildirim adası (Android): kamera çevresinde, bildirim gelince
/// genişleyen siyah hap. Uygulamada canlı önizleme; Android'de bildirim
/// dinleyicisi + kaplama penceresi (IslandNotificationService, IslandOverlay).
/// İki sistem iznini kullanıcı kendisi açar. Varsayılan olarak yalnız
/// uygulamanın simgesi ve adı gösterilir; başlık isteğe bağlıdır ve
/// saklanmaz. Erişilebilirlik hizmeti kullanılmaz (Play politikası).
/// iOS ve web: yalnız önizleme ve dürüst açıklama.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:studio_core/apps/apps.dart';

import '../common.dart';
import '../core.dart';
import '../ek4_core.dart';
import '../platform/native.dart';

/// Adanın uygulama içi çizimi (önizleme).
class IslandPreview extends StatelessWidget {
  final IslandPrefs p;
  final bool expanded;
  final String label, title;
  final double screenWidth;
  const IslandPreview({
    super.key,
    required this.p,
    required this.expanded,
    required this.label,
    required this.title,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    final (w1, h1) = islandExpanded(p.width, p.height, screenWidth);
    final w = expanded ? w1 : p.width;
    final h = expanded ? h1 : p.height;
    final accent = Color(kPalettes[p.palette][2]);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      width: w,
      height: h,
      margin: EdgeInsets.only(top: p.offset),
      padding: EdgeInsets.symmetric(horizontal: h * 0.22),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(h / 2),
        border: Border.all(color: accent.withValues(alpha: expanded ? 0.8 : 0.35), width: 1.5),
      ),
      child: expanded
          ? Row(children: [
              CircleAvatar(
                radius: h * 0.3,
                backgroundColor: accent,
                child: Icon(Icons.chat_bubble_rounded, size: h * 0.3, color: Colors.black87),
              ),
              SizedBox(width: h * 0.18),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  if (p.showTitle)
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ]),
              ),
            ])
          : null,
    );
  }
}

class IslandTool extends StatefulWidget {
  final ToolContext t;
  const IslandTool(this.t, {super.key});
  @override
  State<IslandTool> createState() => _IslandState();
}

class _IslandState extends State<IslandTool> with WidgetsBindingObserver {
  ToolContext get t => widget.t;
  IslandPrefs _p = const IslandPrefs();
  bool _extras = false, _listener = false, _overlay = false, _expanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    () async {
      final m = await t.store.readMap('island');
      final ex = await extrasOpen(t);
      if (!mounted) return;
      setState(() {
        _p = IslandPrefs.fromJson(m);
        _extras = ex;
        if (!_extras && _p.palette >= kFreePalettes) _p = _p.copy(palette: 0);
      });
      if (KisiselNative.android) {
        await KisiselNative.enable(NativeFeature.island);
        await _refresh();
        await KisiselNative.setPrefs(NativeFeature.island, _p.native());
      }
    }();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && KisiselNative.android) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final s = await KisiselNative.featureStatus(NativeFeature.island);
    if (!mounted) return;
    setState(() {
      _listener = s.listener;
      _overlay = s.overlay;
    });
    if (_p.enabled && !(s.listener && s.overlay)) _set(_p.copy(enabled: false));
  }

  void _set(IslandPrefs p) {
    setState(() => _p = p);
    t.store.writeMap('island', p.toJson());
    if (KisiselNative.android) KisiselNative.setPrefs(NativeFeature.island, p.native());
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    return ToolList(children: [
      AppPanel(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              height: 170,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(kPalettes[_p.palette][1]), Color(kPalettes[_p.palette][0])],
                ),
              ),
              alignment: Alignment.topCenter,
              child: IslandPreview(
                p: _p,
                expanded: _expanded,
                label: L(t, 'icon_message'),
                title: L(t, 'isl_sample'),
                screenWidth: (screenW - 32).clamp(200.0, 600.0),
              ),
            ),
          ),
        ),
      ),
      if (KisiselNative.android) ...[
        AppHeading(L(t, 'on_notifications'), icon: Icons.notifications_rounded),
        AppPanel(
          child: Column(children: [
            PermRow(t: t, label: L(t, 'notif_access'), ok: _listener, open: () => KisiselNative.openListenerAccess(NativeFeature.island)),
            PermRow(t: t, label: L(t, 'overlay_perm'), ok: _overlay, open: KisiselNative.openOverlaySettings),
            switchRow(L(t, 'isl_enable'), _p.enabled, (_listener && _overlay) ? (b) => _set(_p.copy(enabled: b)) : null),
            if (_overlay)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  icon: const Icon(Icons.bolt_rounded),
                  label: Text(L(t, 'test_now')),
                  onPressed: () async {
                    await KisiselNative.setPrefs(NativeFeature.island, _p.native());
                    await KisiselNative.testIsland(L(t, 'isl_sample'));
                  },
                ),
              ),
          ]),
        ),
      ],
      AppPanel(
        child: Column(children: [
          SliderRow(label: L(t, 'isl_width'), value: _p.width, min: 80, max: 220, onChanged: (v) => _set(_p.copy(width: v.roundToDouble()))),
          SliderRow(label: L(t, 'isl_height'), value: _p.height, min: 24, max: 48, onChanged: (v) => _set(_p.copy(height: v.roundToDouble()))),
          SliderRow(label: L(t, 'isl_offset'), value: _p.offset, min: 0, max: 60, onChanged: (v) => _set(_p.copy(offset: v.roundToDouble()))),
          SliderRow(
            label: L(t, 'duration'),
            value: _p.seconds,
            min: 2,
            max: 10,
            unit: ' s',
            onChanged: (v) => _set(_p.copy(seconds: v.roundToDouble())),
          ),
          switchRow(L(t, 'isl_charging'), _p.charging, (b) => _set(_p.copy(charging: b))),
          switchRow(L(t, 'isl_idle'), _p.idle, (b) => _set(_p.copy(idle: b))),
          switchRow(L(t, 'isl_show_title'), _p.showTitle, (b) => _set(_p.copy(showTitle: b))),
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
      AppInfoCard(L(t, 'isl_title_note'), icon: Icons.privacy_tip_outlined),
      AppInfoCard(L(t, KisiselNative.android ? 'isl_note_android' : 'isl_note_other'), icon: Icons.info_outline_rounded),
    ]);
  }
}
