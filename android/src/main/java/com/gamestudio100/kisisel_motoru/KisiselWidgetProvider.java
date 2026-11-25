package com.gamestudio100.kisisel_motoru;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Shader;
import android.os.BatteryManager;
import android.os.Bundle;
import android.view.View;
import android.widget.RemoteViews;

import org.json.JSONObject;

/**
 * Ana ekran widget'larının ortak tabanı. Veriyi Flutter, home_widget
 * paketiyle "HomeWidgetPreferences" içine "w_<tür>" anahtarıyla JSON olarak
 * yazar: renkler (c0, c1, c2, fg), başlık, metin, tarih (ms) ve çevrilmiş
 * kısa etiketler. Her widget, panodaki kendi türünün ilk kutucuğunu gösterir.
 */
public abstract class KisiselWidgetProvider extends AppWidgetProvider {
    static final String HOME_WIDGET_PREFS = "HomeWidgetPreferences";

    /** "clock", "date", "countdown", "note" ya da "battery". */
    protected abstract String type();

    @Override
    public void onUpdate(Context context, AppWidgetManager manager, int[] ids) {
        for (int id : ids) update(context, manager, id);
    }

    @Override
    public void onAppWidgetOptionsChanged(Context context, AppWidgetManager manager, int id, Bundle options) {
        update(context, manager, id);
    }

    static JSONObject data(Context c, String type) {
        SharedPreferences p = c.getSharedPreferences(HOME_WIDGET_PREFS, Context.MODE_PRIVATE);
        Object raw = p.getAll().get("w_" + type);
        if (raw instanceof String) {
            try {
                return new JSONObject((String) raw);
            } catch (Exception ignored) {
            }
        }
        return new JSONObject();
    }

    private void update(Context context, AppWidgetManager manager, int id) {
        String t = type();
        JSONObject j = data(context, t);
        int layout = "clock".equals(t) ? R.layout.kisisel_widget_clock
            : "date".equals(t) ? R.layout.kisisel_widget_date
            : R.layout.kisisel_widget_text;
        RemoteViews v = new RemoteViews(context.getPackageName(), layout);
        int c0 = (int) j.optLong("c0", NativePrefs.DEFAULT_COLORS[0] & 0xFFFFFFFFL);
        int c1 = (int) j.optLong("c1", NativePrefs.DEFAULT_COLORS[1] & 0xFFFFFFFFL);
        int c2 = (int) j.optLong("c2", NativePrefs.DEFAULT_COLORS[2] & 0xFFFFFFFFL);
        int fg = (int) j.optLong("fg", NativePrefs.DEFAULT_COLORS[3] & 0xFFFFFFFFL);
        v.setImageViewBitmap(R.id.kw_bg, background(context, c0, c1, c2));
        int sub = (fg & 0x00FFFFFF) | 0xCC000000;
        if ("clock".equals(t) || "date".equals(t)) {
            v.setTextColor(R.id.kw_time, fg);
            v.setTextColor(R.id.kw_sub, sub);
        } else {
            v.setTextColor(R.id.kw_title, sub);
            v.setTextColor(R.id.kw_big, fg);
            v.setTextColor(R.id.kw_small, sub);
            fillText(context, t, j, v);
        }
        Intent launch = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        if (launch != null) {
            PendingIntent pi = PendingIntent.getActivity(context, 0, launch,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            v.setOnClickPendingIntent(R.id.kw_root, pi);
        }
        manager.updateAppWidget(id, v);
    }

    private static void show(RemoteViews v, int id, String text) {
        if (text == null || text.isEmpty()) {
            v.setViewVisibility(id, View.GONE);
        } else {
            v.setViewVisibility(id, View.VISIBLE);
            v.setTextViewText(id, text);
        }
    }

    private static void fillText(Context c, String t, JSONObject j, RemoteViews v) {
        switch (t) {
            case "countdown": {
                long date = j.optLong("date", 0);
                show(v, R.id.kw_title, j.optString("title", ""));
                if (date <= 0) {
                    show(v, R.id.kw_big, "…");
                    show(v, R.id.kw_small, j.optString("pick", ""));
                    break;
                }
                long diff = date - System.currentTimeMillis();
                if (diff < 0) {
                    v.setTextViewTextSize(R.id.kw_big, android.util.TypedValue.COMPLEX_UNIT_SP, 22);
                    show(v, R.id.kw_big, j.optString("passed", "0"));
                    show(v, R.id.kw_small, "");
                } else {
                    long days = diff / 86400000L;
                    long hours = (diff % 86400000L) / 3600000L;
                    v.setTextViewTextSize(R.id.kw_big, android.util.TypedValue.COMPLEX_UNIT_SP, 34);
                    show(v, R.id.kw_big, String.valueOf(days));
                    show(v, R.id.kw_small, j.optString("days", "") + " · " + hours + " " + j.optString("hours", ""));
                }
                break;
            }
            case "note":
                show(v, R.id.kw_title, j.optString("title", ""));
                v.setTextViewTextSize(R.id.kw_big, android.util.TypedValue.COMPLEX_UNIT_SP, 18);
                String text = j.optString("text", "");
                show(v, R.id.kw_big, text.isEmpty() ? "…" : text);
                show(v, R.id.kw_small, "");
                break;
            default: {
                BatteryManager bm = (BatteryManager) c.getSystemService(Context.BATTERY_SERVICE);
                int level = bm == null ? -1 : bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY);
                show(v, R.id.kw_title, j.optString("label", ""));
                show(v, R.id.kw_big, level < 0 || level > 100 ? "—" : "%" + level);
                show(v, R.id.kw_small, "");
            }
        }
    }

    /** Yuvarlak köşeli degrade arka plan (uygulamadaki kutucuk gibi). */
    private static Bitmap background(Context c, int c0, int c1, int c2) {
        float d = c.getResources().getDisplayMetrics().density;
        int size = Math.round(160 * d);
        Bitmap b = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(b);
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setShader(new LinearGradient(0, 0, size, size, c1, c0, Shader.TileMode.CLAMP));
        RectF r = new RectF(0, 0, size, size);
        float radius = 22 * d;
        canvas.drawRoundRect(r, radius, radius, p);
        p.setShader(null);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(1.5f * d);
        p.setColor((c2 & 0x00FFFFFF) | 0x80000000);
        r.inset(d, d);
        canvas.drawRoundRect(r, radius, radius, p);
        return b;
    }
}
