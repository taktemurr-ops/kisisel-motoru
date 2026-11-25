/// Üretilmiş dosya (proto/apps/kisisel/mkengine.py). Kişiselleştirme'nin 5 aracı.
library;

import 'package:flutter/material.dart';
import 'package:studio_core/apps/apps.dart';

import 'tools/clock.dart';
import 'tools/icons.dart';
import 'tools/sounds.dart';
import 'tools/wallpaper.dart';
import 'tools/widgets_pack.dart';
import 'tx.dart';

/// Kategoriler (merkezdeki çip sırası).
final List<AppCategory> kisiselCategories = [
  AppCategory(id: 'screen', title: kKisCat['cat_screen']!, icon: Icons.smartphone_rounded),
  AppCategory(id: 'sound', title: kKisCat['cat_sound']!, icon: Icons.graphic_eq_rounded),
];

/// Bütün araçlar (katalog sırası).
final List<AppTool> kisiselTools = [
  AppTool(
    id: 'uyg-canli-duvar-kagidi',
    title: kKisTitle['uyg-canli-duvar-kagidi']!,
    tagline: kKisTag['uyg-canli-duvar-kagidi']!,
    icon: Icons.wallpaper_rounded,
    color: const Color(0xFF7E57C2),
    category: 'screen',
    keywords: const ['wallpaper', 'live', 'duvar'],
    builder: (context, t) => WallpaperTool(t),
  ),
  AppTool(
    id: 'uyg-widget-paketi',
    title: kKisTitle['uyg-widget-paketi']!,
    tagline: kKisTag['uyg-widget-paketi']!,
    icon: Icons.widgets_rounded,
    color: const Color(0xFF26A69A),
    category: 'screen',
    keywords: const ['widget', 'clock', 'countdown'],
    builder: (context, t) => WidgetPackTool(t),
  ),
  AppTool(
    id: 'uyg-ozgun-ikon-paketi',
    title: kKisTitle['uyg-ozgun-ikon-paketi']!,
    tagline: kKisTag['uyg-ozgun-ikon-paketi']!,
    icon: Icons.apps_rounded,
    color: const Color(0xFFFF8A65),
    category: 'screen',
    keywords: const ['icon', 'ikon', 'png'],
    builder: (context, t) => IconPackTool(t),
  ),
  AppTool(
    id: 'uyg-bildirim-ve-zil-sesi-paketi',
    title: kKisTitle['uyg-bildirim-ve-zil-sesi-paketi']!,
    tagline: kKisTag['uyg-bildirim-ve-zil-sesi-paketi']!,
    icon: Icons.music_note_rounded,
    color: const Color(0xFF42A5F5),
    category: 'sound',
    keywords: const ['ringtone', 'notification', 'wav'],
    builder: (context, t) => SoundPackTool(t),
  ),
  AppTool(
    id: 'uyg-kilit-ekrani-saati',
    title: kKisTitle['uyg-kilit-ekrani-saati']!,
    tagline: kKisTag['uyg-kilit-ekrani-saati']!,
    icon: Icons.bedtime_rounded,
    color: const Color(0xFF5C6BC0),
    category: 'screen',
    keywords: const ['clock', 'charging', 'screensaver', 'saat'],
    builder: (context, t) => ChargeClockTool(t),
  ),
];

/// Depo adıyla araç (ör. 'uyg-widget-paketi').
AppTool kisiselTool(String id) => kisiselTools.firstWhere((t) => t.id == id);

/// Merkezin başlığı ve kısa açıklaması.
final List<String> kisiselHubTitle = kKisCat['hub_title']!;
final List<String> kisiselHubTagline = kKisCat['hub_tag']!;

/// Onaylı merkez tasarımının gece moru tonu.
const ApprovedHubStyle kisiselHubStyle = ApprovedHubStyle(
  background: [Color(0xFF2A1B4A), Color(0xFF1A1030), Color(0xFF0D0819)],
  accent: Color(0xFFB794F4),
  card: Color(0xFF3B2A63),
  play: Color(0xFF805AD5),
  number: Colors.white,
);

/// Öne çıkanlar.
const List<String> kisiselFeatured = [
  'uyg-bildirim-ve-zil-sesi-paketi', 'uyg-canli-duvar-kagidi', 'uyg-kilit-ekrani-saati',
];
