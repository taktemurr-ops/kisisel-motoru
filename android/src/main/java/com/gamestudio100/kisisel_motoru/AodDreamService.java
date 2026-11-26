package com.gamestudio100.kisisel_motoru;

import android.app.AlarmManager;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.os.BatteryManager;
import android.os.Handler;
import android.os.Looper;
import android.service.dreams.DreamService;
import android.text.format.DateFormat;
import android.view.View;

import org.json.JSONObject;

import java.util.Calendar;
import java.util.Locale;

/**
 * Her zaman açık ekran (AOD) görünümü: sistem ekran koruyucusu olarak
 * (şarjda / yuvada). Uygulamadaki AOD ile aynı yüzler: "alt alta" rakamlar,
 * pil halkası, sade kadran; tarih, pil, sonraki alarm ve kısa not. Siyah
 * zemin, düşük parlaklık ve dakikada bir kayma (ekran yanığı koruması).
 */
public class AodDreamService extends DreamService {
    @Override
    public void onAttachedToWindow() {
        super.onAttachedToWindow();
        setInteractive(false);
        setFullscreen(true);
        setScreenBright(false);
        setContentView(new AodView(this, readPrefs(this)));
    }

    static JSONObject readPrefs(Context c) {
        try {
            return new JSONObject(NativePrefs.get(c).getString("aod_json", "{}"));
        } catch (Exception e) {
            return new JSONObject();
        }
    }

    /** Sonraki alarmın zamanı (ms) ya da -1. İzin gerektirmez. */
    static long nextAlarm(Context c) {
        AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
        if (am == null) return -1;
        AlarmManager.AlarmClockInfo info = am.getNextAlarmClock();
        return info == null ? -1 : info.getTriggerTime();
    }

    static final class AodView extends View {
        private final Handler handler = new Handler(Looper.getMainLooper());
        private final Paint big = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint small = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint line = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final RectF arc = new RectF();
        private final String face, note;
        private final boolean date, battery, alarm, shift;
        private final int fg, accent;
        private final double dim;
        private final Runnable tick;

        AodView(Context c, JSONObject j) {
            super(c);
            face = j.optString("face", "stacked");
            note = j.optString("note", "").trim();
            date = j.optBoolean("date", true);
            battery = j.optBoolean("battery", true);
            alarm = j.optBoolean("alarm", true);
            shift = j.optBoolean("shift", true);
            dim = Math.max(0, Math.min(0.8, j.optDouble("dim", 0.3)));
            fg = (int) j.optLong("fg", 0xFFE2E8F0L);
            accent = (int) j.optLong("accent", 0xFF4FD1C5L);
            setBackgroundColor(Color.BLACK);
            big.setColor(fg);
            big.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
            big.setTextAlign(Paint.Align.CENTER);
            small.setColor(fg);
            small.setAlpha(190);
            small.setTextAlign(Paint.Align.CENTER);
            line.setStrokeCap(Paint.Cap.ROUND);
            line.setStyle(Paint.Style.STROKE);
            tick = new Runnable() {
                @Override
                public void run() {
                    invalidate();
                    handler.postDelayed(this, 60000 - System.currentTimeMillis() % 60000);
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
            int minuteOfDay = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE);
            double a = minuteOfDay * 0.37;
            float ox = shift ? (float) Math.sin(a) * w * 0.08f : 0;
            float oy = shift ? (float) Math.cos(a * 1.3) * h * 0.06f : 0;
            float cx = w / 2 + ox, cy = h * 0.42f + oy;
            float unit = Math.min(w, h);
            boolean h24 = DateFormat.is24HourFormat(getContext());
            String hh = DateFormat.format(h24 ? "HH" : "h", now).toString();
            String mm = DateFormat.format("mm", now).toString();
            int lvl = level();
            float bottom;
            if ("ring".equals(face)) {
                float r = unit * 0.3f;
                line.setStrokeWidth(unit * 0.012f);
                line.setColor(fg);
                line.setAlpha(60);
                arc.set(cx - r, cy - r, cx + r, cy + r);
                canvas.drawOval(arc, line);
                line.setColor(accent);
                line.setAlpha(255);
                canvas.drawArc(arc, -90, 360f * Math.max(0, lvl) / 100f, false, line);
                big.setTextSize(unit * 0.17f);
                canvas.drawText(hh + ":" + mm, cx, cy + big.getTextSize() * 0.35f, big);
                bottom = cy + r + unit * 0.08f;
            } else if ("minimal".equals(face)) {
                float r = unit * 0.28f;
                double m = now.get(Calendar.MINUTE);
                double hr = now.get(Calendar.HOUR) + m / 60.0;
                hand(canvas, cx, cy, hr / 12 * 2 * Math.PI, r * 0.55f, unit * 0.014f, fg);
                hand(canvas, cx, cy, m / 60 * 2 * Math.PI, r * 0.9f, unit * 0.008f, fg);
                line.setColor(accent);
                line.setStyle(Paint.Style.FILL);
                canvas.drawCircle(cx, cy, unit * 0.012f, line);
                canvas.drawCircle(cx, cy - r, unit * 0.008f, line);
                line.setStyle(Paint.Style.STROKE);
                bottom = cy + r + unit * 0.08f;
            } else {
                big.setTextSize(unit * 0.3f);
                canvas.drawText(hh, cx, cy - unit * 0.02f, big);
                big.setColor(accent);
                canvas.drawText(mm, cx, cy + unit * 0.26f, big);
                big.setColor(fg);
                bottom = cy + unit * 0.36f;
            }
            small.setTextSize(unit * 0.045f);
            float lineH = unit * 0.065f;
            if (date) {
                String d = DateFormat.format(DateFormat.getBestDateTimePattern(Locale.getDefault(), "EEEEdMMMM"), now).toString();
                canvas.drawText(d, cx, bottom, small);
                bottom += lineH;
            }
            StringBuilder info = new StringBuilder();
            if (battery && lvl >= 0) info.append('%').append(lvl);
            if (alarm) {
                long t = nextAlarm(getContext());
                if (t > 0) {
                    Calendar ac = Calendar.getInstance();
                    ac.setTimeInMillis(t);
                    if (info.length() > 0) info.append("   ");
                    info.append("⏰ ").append(DateFormat.format(h24 ? "HH:mm" : "h:mm a", ac));
                }
            }
            if (info.length() > 0) {
                canvas.drawText(info.toString(), cx, bottom, small);
                bottom += lineH;
            }
            if (!note.isEmpty()) {
                small.setColor(accent);
                canvas.drawText(note.length() > 40 ? note.substring(0, 40) : note, cx, bottom, small);
                small.setColor(fg);
                small.setAlpha(190);
            }
            if (dim > 0) canvas.drawColor(Color.argb((int) (dim * 255), 0, 0, 0));
        }

        private void hand(Canvas canvas, float cx, float cy, double ang, float len, float width, int color) {
            line.setColor(color);
            line.setAlpha(255);
            line.setStrokeWidth(width);
            canvas.drawLine(cx, cy, cx + (float) Math.sin(ang) * len, cy - (float) Math.cos(ang) * len, line);
        }
    }
}
