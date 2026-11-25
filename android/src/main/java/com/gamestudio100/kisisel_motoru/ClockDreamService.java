package com.gamestudio100.kisisel_motoru;

import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.os.BatteryManager;
import android.os.Handler;
import android.os.Looper;
import android.service.dreams.DreamService;
import android.text.format.DateFormat;
import android.view.View;

import org.json.JSONObject;

import java.util.Calendar;

/**
 * Sistem ekran koruyucusu (Android "Ekran koruyucu" / Daydream): uygulamadaki
 * şarj saatiyle aynı ayarlar (dijital/analog, saniye, tarih, pil, gece kırmızısı,
 * karartma). Ekran yanığına karşı konum dakikada bir kayar.
 */
public class ClockDreamService extends DreamService {
    @Override
    public void onAttachedToWindow() {
        super.onAttachedToWindow();
        setInteractive(false);
        setFullscreen(true);
        ClockView v = new ClockView(this, readPrefs(this));
        setScreenBright(v.dim <= 0.01);
        setContentView(v);
    }

    static JSONObject readPrefs(Context c) {
        SharedPreferences p = NativePrefs.get(c);
        try {
            return new JSONObject(p.getString("dream_json", "{}"));
        } catch (Exception e) {
            return new JSONObject();
        }
    }

    static final class ClockView extends View {
        private final Handler handler = new Handler(Looper.getMainLooper());
        private final Paint big = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint small = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint line = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final boolean analog, seconds, date, battery;
        private final int fg, accent;
        final double dim;
        private final Runnable tick;

        ClockView(Context c, JSONObject j) {
            super(c);
            analog = j.optBoolean("analog", false);
            seconds = j.optBoolean("seconds", false);
            date = j.optBoolean("date", true);
            battery = j.optBoolean("battery", true);
            boolean night = j.optBoolean("night", false);
            dim = Math.max(0, Math.min(0.8, j.optDouble("dim", 0)));
            int f = (int) j.optLong("fg", 0xFF9AE6B4L);
            int a = (int) j.optLong("accent", 0xFF4FD1C5L);
            fg = night ? 0xFFB3261E : f;
            accent = night ? 0xFF7A1A14 : a;
            setBackgroundColor(Color.BLACK);
            big.setColor(fg);
            big.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));
            big.setTextAlign(Paint.Align.CENTER);
            small.setColor(fg);
            small.setAlpha(200);
            small.setTextAlign(Paint.Align.CENTER);
            line.setStrokeCap(Paint.Cap.ROUND);
            final boolean everySecond = seconds;
            tick = new Runnable() {
                @Override
                public void run() {
                    invalidate();
                    long now = System.currentTimeMillis();
                    handler.postDelayed(this, everySecond ? 1000 - now % 1000 : 60000 - now % 60000);
                }
            };
        }

        @Override
        protected void onAttachedToWindow() {
            super.onAttachedToWindow();
            handler.post(tick);
        }

        @Override
        protected void onDetachedFromWindow() {
            handler.removeCallbacks(tick);
            super.onDetachedFromWindow();
        }

        /** Dart burnInOffset ile aynı fikir: dakikaya bağlı küçük kayma (-1..1). */
        private static float[] burnIn(int minuteOfDay) {
            double a = minuteOfDay * 0.37;
            return new float[] {(float) Math.sin(a), (float) Math.cos(a * 1.3)};
        }

        private int level() {
            BatteryManager bm = (BatteryManager) getContext().getSystemService(Context.BATTERY_SERVICE);
            int l = bm == null ? -1 : bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY);
            return l < 0 || l > 100 ? -1 : l;
        }

        @Override
        protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            float w = getWidth(), h = getHeight();
            Calendar now = Calendar.getInstance();
            float[] off = burnIn(now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE));
            float cx = w / 2 + off[0] * w * 0.06f;
            float cy = h / 2 + off[1] * h * 0.06f;
            float unit = Math.min(w, h);
            String sub = "";
            if (date) sub = DateFormat.format(DateFormat.getBestDateTimePattern(java.util.Locale.getDefault(), "EEEEdMMMM"), now).toString();
            if (battery) {
                int l = level();
                if (l >= 0) sub = sub.isEmpty() ? "%" + l : sub + "  ·  %" + l;
            }
            small.setTextSize(unit * 0.05f);
            if (analog) {
                float r = unit * 0.32f;
                drawDial(canvas, cx, cy - unit * 0.04f, r, now);
                if (!sub.isEmpty()) canvas.drawText(sub, cx, cy + r + unit * 0.06f, small);
            } else {
                String pattern = DateFormat.is24HourFormat(getContext())
                    ? (seconds ? "HH:mm:ss" : "HH:mm")
                    : (seconds ? "h:mm:ss" : "h:mm");
                String time = DateFormat.format(pattern, now).toString();
                big.setTextSize(unit * (seconds ? 0.2f : 0.26f));
                canvas.drawText(time, cx, cy, big);
                if (!sub.isEmpty()) canvas.drawText(sub, cx, cy + unit * 0.1f, small);
            }
            if (dim > 0) canvas.drawColor(Color.argb((int) (dim * 255), 0, 0, 0));
        }

        private void drawDial(Canvas canvas, float cx, float cy, float r, Calendar now) {
            line.setColor(fg);
            for (int i = 0; i < 12; i++) {
                double a = i * Math.PI / 6;
                float in = i % 3 == 0 ? r * 0.82f : r * 0.9f;
                line.setStrokeWidth(i % 3 == 0 ? r * 0.035f : r * 0.018f);
                line.setAlpha(i % 3 == 0 ? 255 : 150);
                canvas.drawLine(cx + (float) Math.sin(a) * in, cy - (float) Math.cos(a) * in,
                    cx + (float) Math.sin(a) * r, cy - (float) Math.cos(a) * r, line);
            }
            line.setAlpha(255);
            double m = now.get(Calendar.MINUTE) + now.get(Calendar.SECOND) / 60.0;
            double hr = now.get(Calendar.HOUR) + m / 60.0;
            hand(canvas, cx, cy, hr / 12 * 2 * Math.PI, r * 0.5f, r * 0.06f, fg);
            hand(canvas, cx, cy, m / 60 * 2 * Math.PI, r * 0.75f, r * 0.04f, fg);
            if (seconds) hand(canvas, cx, cy, now.get(Calendar.SECOND) / 60.0 * 2 * Math.PI, r * 0.82f, r * 0.015f, accent);
            line.setColor(accent);
            line.setStyle(Paint.Style.FILL);
            canvas.drawCircle(cx, cy, r * 0.045f, line);
            line.setStyle(Paint.Style.STROKE);
        }

        private void hand(Canvas canvas, float cx, float cy, double a, float len, float width, int color) {
            line.setColor(color);
            line.setStrokeWidth(width);
            canvas.drawLine(cx, cy, cx + (float) Math.sin(a) * len, cy - (float) Math.cos(a) * len, line);
        }
    }
}
