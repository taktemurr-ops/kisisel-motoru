package com.gamestudio100.kisisel_motoru;

import android.content.Context;
import android.content.SharedPreferences;

/** Flutter tarafından yazılan yerel ayarlar (duvar kağıdı ve ekran koruyucu). */
final class NativePrefs {
    static final String NAME = "kisisel_motoru_native";

    /** Varsayılan palet: "gece denizi" (Dart kPalettes[0] ile aynı). */
    static final int[] DEFAULT_COLORS = {
        0xFF0B1E3F, 0xFF1B3B6F, 0xFF4FD1C5, 0xFF9AE6B4, 0xFFF6E05E
    };

    private NativePrefs() {}

    static SharedPreferences get(Context c) {
        return c.getSharedPreferences(NAME, Context.MODE_PRIVATE);
    }

    static int[] colors(SharedPreferences p, String key) {
        String s = p.getString(key, null);
        if (s == null || s.isEmpty()) return DEFAULT_COLORS.clone();
        String[] parts = s.split(",");
        int[] out = new int[Math.max(parts.length, 1)];
        try {
            for (int i = 0; i < parts.length; i++) out[i] = (int) Long.parseLong(parts[i].trim());
        } catch (NumberFormatException e) {
            return DEFAULT_COLORS.clone();
        }
        return parts.length >= 2 ? out : DEFAULT_COLORS.clone();
    }

    static String joinColors(java.util.List<?> list) {
        StringBuilder b = new StringBuilder();
        for (Object o : list) {
            if (!(o instanceof Number)) continue;
            if (b.length() > 0) b.append(',');
            b.append(((Number) o).longValue() & 0xFFFFFFFFL);
        }
        return b.toString();
    }
}
