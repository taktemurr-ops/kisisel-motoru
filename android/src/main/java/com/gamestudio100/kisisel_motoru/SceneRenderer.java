package com.gamestudio100.kisisel_motoru;

import android.graphics.BlurMaskFilter;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Shader;

/**
 * Canlı duvar kağıdı sahneleri. Dart'taki ScenePainter (lib/src/tools/
 * wallpaper.dart) ile aynı matematik: aurora, dalgalar, baloncuklar,
 * yıldızlar, yörüngeler, yağmur.
 */
final class SceneRenderer {
    private final Paint fill = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint stroke = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint blur = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path path = new Path();
    private final float density;

    String scene = "aurora";
    int[] colors = NativePrefs.DEFAULT_COLORS.clone();

    SceneRenderer(float density) {
        this.density = density <= 0 ? 1f : density;
        stroke.setStyle(Paint.Style.STROKE);
        stroke.setStrokeCap(Paint.Cap.ROUND);
        blur.setMaskFilter(new BlurMaskFilter(18 * this.density, BlurMaskFilter.Blur.NORMAL));
    }

    private int c(int i, double a) {
        int col = colors[((i % colors.length) + colors.length) % colors.length];
        int alpha = (int) Math.round(Math.max(0, Math.min(1, a)) * 255);
        return Color.argb(alpha, Color.red(col), Color.green(col), Color.blue(col));
    }

    private int c(int i) {
        return c(i, 1);
    }

    private static double rnd(int i, int k) {
        double x = Math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
        return x - Math.floor(x);
    }

    /** Sahneyi verilen boyuta ve zamana (saniye) göre çizer. */
    void draw(Canvas canvas, float w, float h, double time) {
        fill.setShader(new LinearGradient(0, 0, 0, h, c(0), c(1), Shader.TileMode.CLAMP));
        canvas.drawRect(0, 0, w, h, fill);
        fill.setShader(null);
        // Dart çizimi mantıksal piksellerle yapar; burada ölçek uygulanır.
        canvas.save();
        canvas.scale(density, density);
        float sw = w / density, sh = h / density;
        switch (scene) {
            case "aurora": aurora(canvas, sw, sh, time); break;
            case "waves": waves(canvas, sw, sh, time); break;
            case "bubbles": bubbles(canvas, sw, sh, time); break;
            case "stars": stars(canvas, sw, sh, time); break;
            case "orbits": orbits(canvas, sw, sh, time); break;
            default: rain(canvas, sw, sh, time); break;
        }
        canvas.restore();
    }

    private void aurora(Canvas canvas, float w, float h, double t) {
        for (int b = 0; b < 4; b++) {
            path.reset();
            path.moveTo(0, h);
            for (float x = 0; x <= w; x += 8) {
                double y = h * (0.28 + b * 0.08)
                    + Math.sin(x / w * 4 + t * (0.5 + b * 0.15) + b) * h * 0.06
                    + Math.sin(x / w * 9 - t * 0.7) * h * 0.02;
                path.lineTo(x, (float) y);
            }
            path.lineTo(w, h);
            path.close();
            blur.setShader(new LinearGradient(0, 0, 0, h, c(2 + b, 0.35), c(1, 0), Shader.TileMode.CLAMP));
            canvas.drawPath(path, blur);
        }
        blur.setShader(null);
    }

    private void waves(Canvas canvas, float w, float h, double t) {
        for (int b = 0; b < 5; b++) {
            path.reset();
            path.moveTo(0, h);
            double base = h * (0.45 + b * 0.11);
            for (float x = 0; x <= w; x += 6) {
                path.lineTo(x, (float) (base + Math.sin(x / w * 2 * Math.PI * (1 + b * 0.3) + t * (1 + b * 0.25)) * 18));
            }
            path.lineTo(w, h);
            path.close();
            fill.setColor(c(2 + b, 0.18 + b * 0.08));
            canvas.drawPath(path, fill);
        }
    }

    private void bubbles(Canvas canvas, float w, float h, double t) {
        stroke.setStrokeWidth(1.5f);
        for (int i = 0; i < 40; i++) {
            double speed = 0.03 + rnd(i, 1) * 0.06;
            double y = (1.1 - mod(t * speed + rnd(i, 2), 1.2)) * h;
            double x = rnd(i, 3) * w + Math.sin(t + i) * 12;
            float r = (float) (6 + rnd(i, 4) * 26);
            fill.setColor(c(2 + i % 3, 0.18));
            canvas.drawCircle((float) x, (float) y, r, fill);
            stroke.setColor(c(3, 0.45));
            canvas.drawCircle((float) x, (float) y, r, stroke);
        }
    }

    private void stars(Canvas canvas, float w, float h, double t) {
        for (int i = 0; i < 160; i++) {
            double x = mod(rnd(i, 1) * w + t * 4 * rnd(i, 5), w);
            double y = rnd(i, 2) * h;
            double tw = 0.4 + 0.6 * (0.5 + 0.5 * Math.sin(t * (1 + rnd(i, 3) * 3) + i));
            fill.setColor(c(2 + i % 3, tw));
            canvas.drawCircle((float) x, (float) y, (float) (0.6 + rnd(i, 4) * 1.8), fill);
        }
        float mx = w * 0.75f, my = h * 0.2f;
        fill.setColor(c(4, 0.85));
        canvas.drawCircle(mx, my, 34, fill);
        fill.setColor(c(0));
        canvas.drawCircle(mx + 12, my - 6, 30, fill);
    }

    private void orbits(Canvas canvas, float w, float h, double t) {
        float cx = w / 2, cy = h / 2;
        float r0 = Math.min(w, h) * 0.08f;
        fill.setColor(c(4, 0.9));
        canvas.drawCircle(cx, cy, r0, fill);
        stroke.setStrokeWidth(1);
        for (int k = 1; k <= 5; k++) {
            float r = r0 * (1.4f + k * 0.9f);
            stroke.setColor(c(3, 0.25));
            canvas.drawCircle(cx, cy, r, stroke);
            double a = t * (0.6 / k) + k;
            fill.setColor(c(2 + k));
            canvas.drawCircle((float) (cx + Math.cos(a) * r), (float) (cy + Math.sin(a) * r), 4 + k * 1.5f, fill);
        }
    }

    private void rain(Canvas canvas, float w, float h, double t) {
        stroke.setStrokeWidth(1.6f);
        for (int i = 0; i < 90; i++) {
            double speed = 0.25 + rnd(i, 1) * 0.3;
            double y = mod(t * speed + rnd(i, 2), 1.0) * (h + 40) - 20;
            double x = rnd(i, 3) * w;
            stroke.setColor(c(2 + i % 2, 0.25 + rnd(i, 4) * 0.4));
            canvas.drawLine((float) x, (float) y, (float) (x - 4), (float) (y + 18), stroke);
        }
    }

    private static double mod(double a, double m) {
        double r = a % m;
        return r < 0 ? r + m : r;
    }
}
