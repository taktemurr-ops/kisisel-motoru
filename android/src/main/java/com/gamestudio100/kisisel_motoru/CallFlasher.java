package com.gamestudio100.kisisel_motoru;

import android.app.Notification;
import android.content.Context;
import android.graphics.BlurMaskFilter;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.PixelFormat;
import android.graphics.RectF;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraManager;
import android.media.AudioManager;
import android.os.BatteryManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;

import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Gelen aramada feneri (ve isteğe bağlı ekran kenarını) ritimle yakıp söndürür.
 * Kamera açılmaz: CameraManager.setTorchMode yalnız fener ışığını yönetir ve
 * izin gerektirmez. Arama açılınca (ses modu "görüşmede"), bildirim
 * kalkınca ya da süre dolunca durur; fener her durumda kapatılır.
 */
final class CallFlasher {
    private static final Handler MAIN = new Handler(Looper.getMainLooper());
    private static CallFlasher current;

    private final Context context;
    private final String key;
    private final long maxMs;
    private final boolean test;
    private final int[] cycle;
    private final long start = SystemClock.uptimeMillis();
    private String torchId;
    private ScreenFlash screen;
    private int step;

    private CallFlasher(Context c, String key, long maxMs, boolean test, String torchId, boolean screenFlash) {
        this.context = c.getApplicationContext();
        this.key = key;
        this.maxMs = maxMs;
        this.test = test;
        this.torchId = torchId;
        JSONObject p = prefs(context);
        cycle = cycle(p.optString("pattern", "steady"), p.optDouble("speed", 1));
        if (screenFlash) {
            int color = 0xFFFBD38D;
            JSONArray a = p.optJSONArray("colors");
            if (a != null && a.length() > 0) color = (int) a.optLong(0, 0xFFFBD38DL);
            screen = new ScreenFlash(context, color);
        }
    }

    static JSONObject prefs(Context c) {
        try {
            return new JSONObject(NativePrefs.get(c).getString("call_json", "{}"));
        } catch (Exception e) {
            return new JSONObject();
        }
    }

    /** Dart flashCycle ile aynı: açık/kapalı süreleri (ms), hız çarpanıyla. */
    static int[] cycle(String pattern, double speed) {
        int[] base;
        if ("heart".equals(pattern)) base = new int[] {120, 120, 120, 600};
        else if ("fast".equals(pattern)) base = new int[] {80, 80};
        else base = new int[] {300, 300};
        double s = Math.max(0.5, Math.min(2, speed));
        int[] out = new int[base.length];
        for (int i = 0; i < base.length; i++) out[i] = (int) Math.max(30, Math.min(2000, Math.round(base[i] / s)));
        return out;
    }

    /** Flaşı olan kamera (önce arka kamera). Yoksa null. */
    static String torchId(Context c) {
        CameraManager cm = (CameraManager) c.getSystemService(Context.CAMERA_SERVICE);
        if (cm == null) return null;
        String any = null;
        try {
            for (String id : cm.getCameraIdList()) {
                CameraCharacteristics ch = cm.getCameraCharacteristics(id);
                Boolean flash = ch.get(CameraCharacteristics.FLASH_INFO_AVAILABLE);
                if (!Boolean.TRUE.equals(flash)) continue;
                Integer facing = ch.get(CameraCharacteristics.LENS_FACING);
                if (facing != null && facing == CameraCharacteristics.LENS_FACING_BACK) return id;
                if (any == null) any = id;
            }
        } catch (CameraAccessException | RuntimeException e) {
            return any;
        }
        return any;
    }

    static boolean hasFlash(Context c) {
        return torchId(c) != null;
    }

    /** Bildirim çalan (henüz açılmamış) bir arama mı. */
    static boolean isRinging(Context c, Notification n) {
        AudioManager am = (AudioManager) c.getSystemService(Context.AUDIO_SERVICE);
        int mode = am == null ? AudioManager.MODE_NORMAL : am.getMode();
        if (mode == AudioManager.MODE_IN_CALL || mode == AudioManager.MODE_IN_COMMUNICATION) return false;
        // Android 12+ CallStyle: 1 = gelen, 2 = süren, 3 = filtreleme.
        int type = n.extras == null ? 0 : n.extras.getInt("android.callType", 0);
        if (type == 1) return true;
        if (type == 2 || type == 3) return false;
        return mode == AudioManager.MODE_RINGTONE || n.fullScreenIntent != null;
    }

    /** Pil ve sessiz mod koşulları (yalnız gerçek aramada). */
    private static boolean allowed(Context c, JSONObject p) {
        AudioManager am = (AudioManager) c.getSystemService(Context.AUDIO_SERVICE);
        if (p.optBoolean("skipSilent", true) && am != null && am.getRingerMode() != AudioManager.RINGER_MODE_NORMAL) {
            return false;
        }
        int min = (int) Math.max(0, Math.min(50, p.optDouble("minBattery", 15)));
        BatteryManager bm = (BatteryManager) c.getSystemService(Context.BATTERY_SERVICE);
        if (min > 0 && bm != null) {
            int level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY);
            boolean charging = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && bm.isCharging();
            if (level >= 0 && level < min && !charging) return false;
        }
        return true;
    }

    /** Yanıp sönmeyi başlatır; aynı bildirim için zaten sürüyorsa dokunmaz. */
    static boolean start(Context c, String key, long maxMs, boolean test) {
        final Context app = c.getApplicationContext();
        JSONObject p = prefs(app);
        if (!test && !allowed(app, p)) return false;
        final String id = torchId(app);
        final boolean screenFlash = p.optBoolean("screen", false) && EdgeOverlay.canDraw(app);
        if (id == null && !screenFlash) return false;
        MAIN.post(() -> {
            if (current != null) {
                if (current.key.equals(key)) return;
                current.finish();
            }
            current = new CallFlasher(app, key, maxMs, test, id, screenFlash);
            MAIN.post(current.tick);
        });
        return true;
    }

    static void stopIfKey(String key) {
        MAIN.post(() -> {
            if (current != null && current.key.equals(key)) current.finish();
        });
    }

    static void stop() {
        MAIN.post(() -> {
            if (current != null) current.finish();
        });
    }

    private final Runnable tick = new Runnable() {
        @Override
        public void run() {
            if (current != CallFlasher.this) return;
            long elapsed = SystemClock.uptimeMillis() - start;
            if (elapsed > maxMs || (!test && answered())) {
                finish();
                return;
            }
            boolean on = step % 2 == 0;
            setTorch(on);
            if (screen != null) screen.set(on);
            int delay = cycle[step % cycle.length];
            step++;
            MAIN.postDelayed(this, delay);
        }
    };

    private boolean answered() {
        AudioManager am = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        if (am == null) return false;
        int mode = am.getMode();
        return mode == AudioManager.MODE_IN_CALL || mode == AudioManager.MODE_IN_COMMUNICATION;
    }

    private void setTorch(boolean on) {
        if (torchId == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return;
        CameraManager cm = (CameraManager) context.getSystemService(Context.CAMERA_SERVICE);
        if (cm == null) return;
        try {
            cm.setTorchMode(torchId, on);
        } catch (CameraAccessException | RuntimeException e) {
            // Kamera başka bir uygulamada açık: fener bu aramada kullanılmaz.
            torchId = null;
        }
    }

    private void finish() {
        MAIN.removeCallbacks(tick);
        setTorch(false);
        if (screen != null) screen.remove();
        screen = null;
        if (current == this) current = null;
    }

    /** Ekran kenarında yanıp sönen çerçeve (dokunmaları geçirir). */
    static final class ScreenFlash {
        private final WindowManager wm;
        private final BorderView view;
        private boolean attached;

        ScreenFlash(Context c, int color) {
            wm = (WindowManager) c.getSystemService(Context.WINDOW_SERVICE);
            view = new BorderView(c, color);
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
            try {
                wm.addView(view, lp);
                attached = true;
            } catch (RuntimeException ignored) {
            }
        }

        void set(boolean on) {
            if (view.on != on) {
                view.on = on;
                view.invalidate();
            }
        }

        void remove() {
            if (!attached) return;
            attached = false;
            try {
                wm.removeView(view);
            } catch (RuntimeException ignored) {
            }
        }
    }

    static final class BorderView extends View {
        boolean on;
        private final Paint line = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint glow = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final RectF rect = new RectF();
        private final float thickness;

        BorderView(Context c, int color) {
            super(c);
            float d = c.getResources().getDisplayMetrics().density;
            thickness = 10 * d;
            line.setStyle(Paint.Style.STROKE);
            line.setStrokeWidth(thickness);
            line.setColor(color);
            glow.setStyle(Paint.Style.STROKE);
            glow.setStrokeWidth(thickness * 2.4f);
            glow.setColor(color);
            glow.setAlpha(150);
            glow.setMaskFilter(new BlurMaskFilter(thickness, BlurMaskFilter.Blur.NORMAL));
            setLayerType(View.LAYER_TYPE_SOFTWARE, null);
        }

        @Override
        protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            if (!on) return;
            float half = thickness / 2;
            rect.set(half, half, getWidth() - half, getHeight() - half);
            float r = 36 * getResources().getDisplayMetrics().density;
            canvas.drawRoundRect(rect, r, r, glow);
            canvas.drawRoundRect(rect, r, r, line);
        }
    }
}
