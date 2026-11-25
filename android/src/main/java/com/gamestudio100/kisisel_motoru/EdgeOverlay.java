package com.gamestudio100.kisisel_motoru;

import android.content.Context;
import android.graphics.BlurMaskFilter;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.PixelFormat;
import android.graphics.RectF;
import android.graphics.SweepGradient;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.provider.Settings;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;

import org.json.JSONObject;

/**
 * Ekran kenarında birkaç saniye görünen ışık (diğer uygulamaların üzerinde,
 * dokunmaları geçirir). Dart EdgePainter ile aynı biçimler: flow, pulse,
 * rainbow, comet. "Diğer uygulamaların üzerinde göster" izni yoksa hiçbir
 * şey yapmaz.
 */
final class EdgeOverlay {
    private static EdgeOverlay current;

    private final Context context;
    private final WindowManager wm;
    private final EdgeView view;
    private final Handler handler = new Handler(Looper.getMainLooper());

    private EdgeOverlay(Context c, JSONObject prefs) {
        context = c.getApplicationContext();
        wm = (WindowManager) context.getSystemService(Context.WINDOW_SERVICE);
        view = new EdgeView(context, prefs);
    }

    static boolean canDraw(Context c) {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(c);
    }

    static JSONObject prefs(Context c) {
        try {
            return new JSONObject(NativePrefs.get(c).getString("edge_json", "{}"));
        } catch (Exception e) {
            return new JSONObject();
        }
    }

    /** Kenar ışığını gösterir; zaten görünüyorsa süresini uzatır. */
    static boolean show(Context c) {
        if (!canDraw(c)) return false;
        final JSONObject p = prefs(c);
        final long ms = (long) (Math.max(2, Math.min(15, p.optDouble("seconds", 5))) * 1000);
        Handler main = new Handler(Looper.getMainLooper());
        main.post(() -> {
            try {
                if (current == null) {
                    current = new EdgeOverlay(c, p);
                    current.attach();
                }
                current.handler.removeCallbacksAndMessages(null);
                current.handler.postDelayed(EdgeOverlay::hide, ms);
            } catch (RuntimeException e) {
                current = null;
            }
        });
        return true;
    }

    static void hide() {
        EdgeOverlay o = current;
        current = null;
        if (o == null) return;
        o.handler.removeCallbacksAndMessages(null);
        try {
            o.wm.removeView(o.view);
        } catch (RuntimeException ignored) {
        }
    }

    private void attach() {
        int type = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
            ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            : WindowManager.LayoutParams.TYPE_PHONE;
        WindowManager.LayoutParams lp = new WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT);
        lp.gravity = Gravity.TOP | Gravity.START;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
        }
        wm.addView(view, lp);
    }

    /** Kenar ışığı çizimi (uygulamadaki önizlemeyle aynı). */
    static final class EdgeView extends View {
        private final String style;
        private final int[] colors;
        private final float thickness, radius, speed;
        private final long start = SystemClock.uptimeMillis();
        private final Paint line = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint glow = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Matrix matrix = new Matrix();
        private final RectF rect = new RectF();

        EdgeView(Context c, JSONObject p) {
            super(c);
            float d = c.getResources().getDisplayMetrics().density;
            style = p.optString("style", "flow");
            thickness = (float) Math.max(2, Math.min(16, p.optDouble("thickness", 6))) * d;
            radius = (float) Math.max(0, Math.min(60, p.optDouble("radius", 32))) * d;
            speed = (float) Math.max(0.3, Math.min(3, p.optDouble("speed", 1)));
            int[] pal = NativePrefs.colors(NativePrefs.get(c), "edge_colors");
            if ("rainbow".equals(style)) {
                colors = new int[7];
                for (int i = 0; i < 7; i++) colors[i] = Color.HSVToColor(new float[] {(i * 60) % 360, 0.85f, 1f});
            } else if ("comet".equals(style)) {
                int a = pal[0];
                colors = new int[] {a & 0x00FFFFFF, a & 0x00FFFFFF, (a & 0x00FFFFFF) | 0x99000000, Color.WHITE, a & 0x00FFFFFF};
            } else {
                colors = new int[] {pal[0], pal[1 % pal.length], pal[2 % pal.length], pal[0]};
            }
            line.setStyle(Paint.Style.STROKE);
            line.setStrokeWidth(thickness);
            glow.setStyle(Paint.Style.STROKE);
            glow.setStrokeWidth(thickness * 2.2f);
            glow.setMaskFilter(new BlurMaskFilter(thickness, BlurMaskFilter.Blur.NORMAL));
            setLayerType(View.LAYER_TYPE_SOFTWARE, null);
        }

        @Override
        protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            float w = getWidth(), h = getHeight();
            float half = thickness / 2;
            rect.set(half, half, w - half, h - half);
            float t = (SystemClock.uptimeMillis() - start) / 1000f;
            float cx = w / 2, cy = h / 2;
            SweepGradient g;
            float alpha = 1f;
            if ("comet".equals(style)) {
                g = new SweepGradient(cx, cy, colors, new float[] {0f, 0.55f, 0.85f, 0.97f, 1f});
                matrix.setRotate((t * speed * 0.5f % 1f) * 360f, cx, cy);
            } else {
                g = new SweepGradient(cx, cy, colors, null);
                if ("pulse".equals(style)) {
                    matrix.reset();
                    alpha = 0.15f + 0.85f * (0.5f + 0.5f * (float) Math.sin(t * speed * 2 * Math.PI * 0.8));
                } else {
                    matrix.setRotate((float) Math.toDegrees(t * speed * Math.PI), cx, cy);
                }
            }
            g.setLocalMatrix(matrix);
            line.setShader(g);
            glow.setShader(g);
            line.setAlpha((int) (255 * alpha));
            glow.setAlpha((int) (140 * alpha));
            canvas.drawRoundRect(rect, radius, radius, glow);
            canvas.drawRoundRect(rect, radius, radius, line);
            postInvalidateOnAnimation();
        }
    }
}
