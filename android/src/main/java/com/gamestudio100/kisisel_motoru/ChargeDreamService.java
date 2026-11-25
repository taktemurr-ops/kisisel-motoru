package com.gamestudio100.kisisel_motoru;

import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.graphics.BlurMaskFilter;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.SweepGradient;
import android.graphics.Typeface;
import android.os.BatteryManager;
import android.os.SystemClock;
import android.service.dreams.DreamService;
import android.text.format.DateFormat;
import android.view.View;

import org.json.JSONObject;

import java.util.Calendar;
import java.util.Random;

/**
 * Şarj animasyonu ekran koruyucusu: Android'de "Ekran koruyucu → Şarj
 * olurken" seçilince sistem başlatır. Uygulamadaki ChargePainter ile aynı
 * biçimler (liquid, ring, bubbles, bars), pil yüzdesi ve saat.
 */
public class ChargeDreamService extends DreamService {
    @Override
    public void onAttachedToWindow() {
        super.onAttachedToWindow();
        setInteractive(false);
        setFullscreen(true);
        setScreenBright(true);
        setContentView(new ChargeView(this, readPrefs(this)));
    }

    static JSONObject readPrefs(Context c) {
        try {
            return new JSONObject(NativePrefs.get(c).getString("charge_json", "{}"));
        } catch (Exception e) {
            return new JSONObject();
        }
    }

    static final class ChargeView extends View {
        private final String style;
        private final boolean percent, clock;
        private final int a, b, c;
        private final long start = SystemClock.uptimeMillis();
        private final Paint fill = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint stroke = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint text = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint small = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Path path = new Path();
        private final RectF rect = new RectF();
        private final Matrix matrix = new Matrix();
        private int level = -1;
        private boolean charging = true;
        private long lastRead = 0;

        ChargeView(Context ctx, JSONObject p) {
            super(ctx);
            style = p.optString("style", "liquid");
            percent = p.optBoolean("percent", true);
            clock = p.optBoolean("clock", true);
            int[] pal = NativePrefs.colors(NativePrefs.get(ctx), "charge_colors");
            a = pal[0];
            b = pal[1 % pal.length];
            c = pal[2 % pal.length];
            setBackgroundColor(Color.BLACK);
            text.setColor(Color.WHITE);
            text.setTextAlign(Paint.Align.CENTER);
            text.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));
            small.setColor(0xB3FFFFFF);
            small.setTextAlign(Paint.Align.CENTER);
            setLayerType(View.LAYER_TYPE_SOFTWARE, null);
        }

        private void readBattery() {
            long now = SystemClock.uptimeMillis();
            if (now - lastRead < 5000 && level >= 0) return;
            lastRead = now;
            Intent i = getContext().registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
            if (i == null) return;
            int l = i.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
            int s = i.getIntExtra(BatteryManager.EXTRA_SCALE, 100);
            if (l >= 0 && s > 0) level = Math.round(l * 100f / s);
            int st = i.getIntExtra(BatteryManager.EXTRA_STATUS, -1);
            charging = st == BatteryManager.BATTERY_STATUS_CHARGING || st == BatteryManager.BATTERY_STATUS_FULL;
        }

        /** Dart liquidSurface ile aynı. */
        private static float surface(float lv, float x, float t) {
            float amp = 0.018f * (1 - Math.abs(2 * lv - 1) * 0.6f);
            return lv + amp * (float) Math.sin(2 * Math.PI * (x * 1.6 + t * 0.45))
                + amp * 0.6f * (float) Math.sin(2 * Math.PI * (x * 3.1 - t * 0.7));
        }

        @Override
        protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            readBattery();
            float w = getWidth(), h = getHeight();
            float t = (SystemClock.uptimeMillis() - start) / 1000f;
            if (!charging) t *= 0.25f;
            float lv = Math.max(0, Math.min(100, level < 0 ? 50 : level)) / 100f;
            float u = Math.min(w, h);
            fill.setMaskFilter(null);
            fill.setShader(null);
            stroke.setMaskFilter(null);
            stroke.setShader(null);
            switch (style) {
                case "ring": {
                    float r = u * 0.36f, sw = r * 0.12f, cx = w / 2, cy = h / 2;
                    stroke.setStyle(Paint.Style.STROKE);
                    stroke.setStrokeWidth(sw);
                    stroke.setStrokeCap(Paint.Cap.ROUND);
                    stroke.setColor(0x14FFFFFF);
                    canvas.drawCircle(cx, cy, r, stroke);
                    rect.set(cx - r, cy - r, cx + r, cy + r);
                    SweepGradient g = new SweepGradient(cx, cy, new int[] {a, b, c, a}, null);
                    matrix.setRotate((float) Math.toDegrees(t * 0.8), cx, cy);
                    g.setLocalMatrix(matrix);
                    stroke.setShader(g);
                    stroke.setColor(Color.WHITE);
                    float sweep = 360f * Math.max(0.01f, lv);
                    stroke.setMaskFilter(new BlurMaskFilter(sw * 0.8f, BlurMaskFilter.Blur.NORMAL));
                    canvas.drawArc(rect, -90, sweep, false, stroke);
                    stroke.setMaskFilter(null);
                    canvas.drawArc(rect, -90, sweep, false, stroke);
                    break;
                }
                case "bubbles": {
                    float fh = h * lv;
                    fill.setShader(new LinearGradient(0, h - fh, 0, h, (a & 0x00FFFFFF) | 0x73000000,
                        (b & 0x00FFFFFF) | 0x33000000, Shader.TileMode.CLAMP));
                    canvas.drawRect(0, h - fh, w, h, fill);
                    stroke.setStyle(Paint.Style.STROKE);
                    stroke.setStrokeWidth(2 * getResources().getDisplayMetrics().density);
                    int n = 14 + Math.round(lv * 26);
                    for (int i = 0; i < n; i++) {
                        Random r = new Random(i * 7919L + 13);
                        float x = 0.1f + r.nextFloat() * 0.8f;
                        float sp = 0.06f + r.nextFloat() * 0.1f;
                        float ph = r.nextFloat();
                        float y = 1 - ((t * sp + ph) % 1f);
                        float rad = 0.012f + r.nextFloat() * 0.03f;
                        float px = (x + 0.03f * (float) Math.sin(t * 1.3 + i)) * w;
                        float py = h - (1 - y) * fh;
                        stroke.setColor(((i % 2 == 0 ? b : c) & 0x00FFFFFF) | 0xCC000000);
                        canvas.drawCircle(px, py, rad * u, stroke);
                    }
                    break;
                }
                case "bars": {
                    int n = 16;
                    float bw = w / (n * 1.6f);
                    for (int i = 0; i < n; i++) {
                        float wave = 0.5f + 0.5f * (float) Math.sin(t * 3 + i * 0.6);
                        float bh = h * (0.08f + lv * 0.7f * (0.6f + 0.4f * wave));
                        float x = (i + 0.3f) * w / n;
                        rect.set(x, h * 0.9f - bh, x + bw, h * 0.9f);
                        fill.setShader(new LinearGradient(0, rect.bottom, 0, rect.top, a, c, Shader.TileMode.CLAMP));
                        canvas.drawRoundRect(rect, bw / 2, bw / 2, fill);
                    }
                    break;
                }
                default: {
                    for (int layer = 0; layer < 2; layer++) {
                        path.reset();
                        path.moveTo(0, h);
                        for (int i = 0; i <= 48; i++) {
                            float x = i / 48f;
                            float y = surface(lv, x + layer * 0.37f, t * (layer == 0 ? 1f : 1.4f));
                            path.lineTo(x * w, h - y * h);
                        }
                        path.lineTo(w, h);
                        path.close();
                        int top = layer == 0 ? b : ((a & 0x00FFFFFF) | 0x80000000);
                        int bottom = layer == 0 ? a : ((c & 0x00FFFFFF) | 0x66000000);
                        fill.setShader(new LinearGradient(0, 0, 0, h, top, bottom, Shader.TileMode.CLAMP));
                        canvas.drawPath(path, fill);
                    }
                }
            }
            float cy = h / 2;
            if (clock) {
                small.setTextSize(u * 0.09f);
                String pattern = DateFormat.is24HourFormat(getContext()) ? "HH:mm" : "h:mm";
                canvas.drawText(DateFormat.format(pattern, Calendar.getInstance()).toString(), w / 2, cy - u * 0.12f, small);
            }
            if (percent && level >= 0) {
                text.setTextSize(u * 0.16f);
                canvas.drawText("%" + level, w / 2, cy + u * 0.06f, text);
            }
            postInvalidateOnAnimation();
        }
    }
}
