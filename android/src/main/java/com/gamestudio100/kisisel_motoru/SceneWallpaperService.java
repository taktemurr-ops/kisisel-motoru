package com.gamestudio100.kisisel_motoru;

import android.content.SharedPreferences;
import android.graphics.Canvas;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.service.wallpaper.WallpaperService;
import android.view.SurfaceHolder;

/**
 * Sistem canlı duvar kağıdı: uygulamada seçilen sahne, palet ve hız.
 * Yalnız görünürken çizer (saniyede ~30 kare); görünmezken durur, pil yemez.
 */
public class SceneWallpaperService extends WallpaperService {
    @Override
    public Engine onCreateEngine() {
        return new SceneEngine();
    }

    private class SceneEngine extends Engine implements SharedPreferences.OnSharedPreferenceChangeListener {
        private final Handler handler = new Handler(Looper.getMainLooper());
        private final Runnable frame = this::drawFrame;
        private SceneRenderer renderer;
        private SharedPreferences prefs;
        private boolean visible;
        private double time;
        private double speed = 1;
        private long last;
        private int width, height;

        @Override
        public void onCreate(SurfaceHolder holder) {
            super.onCreate(holder);
            renderer = new SceneRenderer(getResources().getDisplayMetrics().density);
            prefs = NativePrefs.get(SceneWallpaperService.this);
            prefs.registerOnSharedPreferenceChangeListener(this);
            load();
        }

        private void load() {
            renderer.scene = prefs.getString("wall_scene", "aurora");
            renderer.colors = NativePrefs.colors(prefs, "wall_colors");
            speed = prefs.getFloat("wall_speed", 1f);
        }

        @Override
        public void onSharedPreferenceChanged(SharedPreferences p, String key) {
            if (key == null || key.startsWith("wall_")) {
                load();
                if (visible) drawFrame();
            }
        }

        @Override
        public void onVisibilityChanged(boolean v) {
            visible = v;
            handler.removeCallbacks(frame);
            if (v) {
                last = SystemClock.elapsedRealtime();
                drawFrame();
            }
        }

        @Override
        public void onSurfaceChanged(SurfaceHolder holder, int format, int w, int h) {
            super.onSurfaceChanged(holder, format, w, h);
            width = w;
            height = h;
            if (visible) drawFrame();
        }

        @Override
        public void onSurfaceDestroyed(SurfaceHolder holder) {
            visible = false;
            handler.removeCallbacks(frame);
            super.onSurfaceDestroyed(holder);
        }

        @Override
        public void onDestroy() {
            handler.removeCallbacks(frame);
            if (prefs != null) prefs.unregisterOnSharedPreferenceChangeListener(this);
            super.onDestroy();
        }

        private void drawFrame() {
            handler.removeCallbacks(frame);
            long now = SystemClock.elapsedRealtime();
            time += (now - last) / 1000.0 * speed;
            last = now;
            SurfaceHolder holder = getSurfaceHolder();
            Canvas canvas = null;
            try {
                canvas = holder.lockCanvas();
                if (canvas != null) {
                    int w = width > 0 ? width : canvas.getWidth();
                    int h = height > 0 ? height : canvas.getHeight();
                    renderer.draw(canvas, w, h, time);
                }
            } catch (RuntimeException ignored) {
                // Yüzey o an kullanılamıyor olabilir; sonraki karede yeniden denenir.
            } finally {
                if (canvas != null) {
                    try {
                        holder.unlockCanvasAndPost(canvas);
                    } catch (RuntimeException ignored) {
                    }
                }
            }
            if (visible) handler.postDelayed(frame, 33);
        }
    }
}
