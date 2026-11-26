package com.gamestudio100.kisisel_motoru;

import android.animation.ValueAnimator;
import android.app.ActivityOptions;
import android.app.Notification;
import android.app.PendingIntent;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.PixelFormat;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.Icon;
import android.os.BatteryManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.TextPaint;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.view.animation.DecelerateInterpolator;

import org.json.JSONObject;

/**
 * Dinamik bildirim adası: kamera çevresinde, diğer uygulamaların üzerinde
 * çizilen siyah hap. Bildirim gelince genişler (simge + uygulama adı, isteğe
 * bağlı başlık), birkaç saniye sonra küçülür; dokununca bildirimi açar.
 * "Diğer uygulamaların üzerinde göster" izni yoksa hiçbir şey yapmaz.
 * Pencere TYPE_APPLICATION_OVERLAY olduğundan durum çubuğunun altında kalır
 * (erişilebilirlik hizmeti kullanılmaz).
 */
final class IslandOverlay {
    private static IslandOverlay current;
    private static final Handler MAIN = new Handler(Looper.getMainLooper());

    /** Gösterilecek içerik. */
    static final class Content {
        Drawable icon;
        String label = "";
        String sub = "";
        int level = -1; // >= 0 ise şarj göstergesi
        PendingIntent tap;
    }

    private final Context context;
    private final WindowManager wm;
    private final IslandView view;
    private final WindowManager.LayoutParams lp;
    private final float density;
    private boolean attached;
    private boolean idleMode;

    private IslandOverlay(Context c) {
        context = c.getApplicationContext();
        wm = (WindowManager) context.getSystemService(Context.WINDOW_SERVICE);
        density = context.getResources().getDisplayMetrics().density;
        view = new IslandView(context);
        int type = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
            ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            : WindowManager.LayoutParams.TYPE_PHONE;
        lp = new WindowManager.LayoutParams(1, 1, type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT);
        lp.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
        }
        view.setOnClickListener(v -> onTap());
    }

    static JSONObject prefs(Context c) {
        try {
            return new JSONObject(NativePrefs.get(c).getString("island_json", "{}"));
        } catch (Exception e) {
            return new JSONObject();
        }
    }

    private static float clamp(double v, double lo, double hi) {
        return (float) Math.max(lo, Math.min(hi, v));
    }

    // ------------------------------------------------------------ giriş

    /** Bir bildirim için adayı gösterir. */
    static void showNotification(Context c, String pkg, Notification n) {
        if (!EdgeOverlay.canDraw(c)) return;
        JSONObject p = prefs(c);
        Content ct = new Content();
        PackageManager pm = c.getPackageManager();
        try {
            ApplicationInfo ai = pm.getApplicationInfo(pkg, 0);
            ct.label = String.valueOf(pm.getApplicationLabel(ai));
            ct.icon = pm.getApplicationIcon(ai);
        } catch (PackageManager.NameNotFoundException | RuntimeException e) {
            ct.label = "";
        }
        if (ct.icon == null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Icon small = n.getSmallIcon();
            if (small != null) {
                try {
                    ct.icon = small.loadDrawable(c);
                    if (ct.icon != null) ct.icon.setTint(Color.WHITE);
                } catch (RuntimeException ignored) {
                }
            }
        }
        if (p.optBoolean("showTitle", false) && n.extras != null) {
            CharSequence t = n.extras.getCharSequence(Notification.EXTRA_TITLE);
            if (t != null) ct.sub = t.toString();
        }
        ct.tap = n.contentIntent;
        show(c, ct);
    }

    /** Şarj takılınca pil düzeyini gösterir. */
    static void showCharging(Context c) {
        if (!EdgeOverlay.canDraw(c)) return;
        Content ct = new Content();
        BatteryManager bm = (BatteryManager) c.getSystemService(Context.BATTERY_SERVICE);
        int l = bm == null ? -1 : bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY);
        ct.level = l < 0 || l > 100 ? 0 : l;
        ct.label = "%" + ct.level;
        show(c, ct);
    }

    /** Uygulamadaki "Şimdi dene" düğmesi: örnek bildirim. */
    static boolean demo(Context c, String sample) {
        if (!EdgeOverlay.canDraw(c)) return false;
        Content ct = new Content();
        PackageManager pm = c.getPackageManager();
        try {
            ct.label = String.valueOf(pm.getApplicationLabel(c.getApplicationInfo()));
            ct.icon = pm.getApplicationIcon(c.getApplicationInfo());
        } catch (RuntimeException ignored) {
        }
        ct.sub = sample == null ? "" : sample;
        show(c, ct);
        return true;
    }

    /** "Boştayken küçük hap" ayarına göre hapı gösterir ya da kaldırır. */
    static void refreshIdle(Context c) {
        final Context app = c.getApplicationContext();
        MAIN.post(() -> {
            JSONObject p = prefs(app);
            boolean want = p.optBoolean("enabled", false) && p.optBoolean("idle", false) && EdgeOverlay.canDraw(app);
            if (want) {
                if (current == null) current = new IslandOverlay(app);
                if (!current.view.expanded) current.collapsedNow(true);
            } else if (current != null && !current.view.expanded) {
                hide();
            }
        });
    }

    static void hide() {
        MAIN.post(() -> {
            IslandOverlay o = current;
            current = null;
            if (o != null) o.detach();
        });
    }

    private static void show(Context c, Content ct) {
        final Context app = c.getApplicationContext();
        MAIN.post(() -> {
            try {
                if (current == null) current = new IslandOverlay(app);
                current.expand(ct);
            } catch (RuntimeException e) {
                IslandOverlay o = current;
                current = null;
                if (o != null) o.detach();
            }
        });
    }

    // ------------------------------------------------------------ pencere

    private void applyPrefs() {
        JSONObject p = prefs(context);
        view.w0 = clamp(p.optDouble("width", 120), 80, 220) * density;
        view.h0 = clamp(p.optDouble("height", 34), 24, 48) * density;
        int screen = context.getResources().getDisplayMetrics().widthPixels;
        view.w1 = Math.min(screen * 0.92f, Math.max(view.w0 * 2.6f, 260 * density));
        view.h1 = Math.max(view.h0 * 2f, 64 * density);
        view.accent = (int) p.optLong("accent", 0xFF4FD1C5L);
        lp.y = Math.round(clamp(p.optDouble("offset", 10), 0, 60) * density);
        idleMode = p.optBoolean("idle", false);
    }

    private void layout(boolean big, boolean touchable) {
        lp.width = Math.round(big ? view.w1 : view.w0) + 2;
        lp.height = Math.round(big ? view.h1 : view.h0) + 2;
        if (touchable) lp.flags &= ~WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE;
        else lp.flags |= WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE;
        if (attached) {
            wm.updateViewLayout(view, lp);
        } else {
            wm.addView(view, lp);
            attached = true;
        }
    }

    private void detach() {
        MAIN.removeCallbacks(collapseTask);
        view.stopAnim();
        if (!attached) return;
        attached = false;
        try {
            wm.removeView(view);
        } catch (RuntimeException ignored) {
        }
    }

    private final Runnable collapseTask = this::collapse;

    private void expand(Content ct) {
        applyPrefs();
        view.content = ct;
        layout(true, true);
        view.animateTo(1f, null);
        MAIN.removeCallbacks(collapseTask);
        long ms = (long) (clamp(prefs(context).optDouble("seconds", 4), 2, 10) * 1000);
        MAIN.postDelayed(collapseTask, ms);
    }

    private void collapse() {
        view.animateTo(0f, () -> {
            if (current != this) return;
            if (idleMode) {
                collapsedNow(false);
            } else {
                current = null;
                detach();
            }
        });
    }

    private void collapsedNow(boolean refresh) {
        if (refresh) applyPrefs();
        view.content = null;
        view.fraction = 0f;
        view.expanded = false;
        layout(false, false);
        view.invalidate();
    }

    private void onTap() {
        Content ct = view.content;
        if (ct != null && ct.tap != null) {
            try {
                if (Build.VERSION.SDK_INT >= 34) {
                    Bundle b = ActivityOptions.makeBasic()
                        .setPendingIntentBackgroundActivityStartMode(ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED)
                        .toBundle();
                    ct.tap.send(context, 0, null, null, null, null, b);
                } else {
                    ct.tap.send();
                }
            } catch (PendingIntent.CanceledException | RuntimeException ignored) {
            }
        }
        MAIN.removeCallbacks(collapseTask);
        collapse();
    }

    // -------------------------------------------------------------- çizim

    static final class IslandView extends View {
        float w0, h0, w1, h1;
        float fraction;
        boolean expanded;
        int accent = 0xFF4FD1C5;
        Content content;
        private ValueAnimator anim;
        private final Paint pill = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint ring = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint fill = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final TextPaint title = new TextPaint(Paint.ANTI_ALIAS_FLAG);
        private final TextPaint sub = new TextPaint(Paint.ANTI_ALIAS_FLAG);
        private final RectF rect = new RectF();

        IslandView(Context c) {
            super(c);
            float d = c.getResources().getDisplayMetrics().density;
            pill.setColor(Color.BLACK);
            ring.setStyle(Paint.Style.STROKE);
            ring.setStrokeWidth(1.5f * d);
            title.setColor(Color.WHITE);
            title.setTextSize(14 * d);
            title.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));
            sub.setColor(0xFFB0B0B0);
            sub.setTextSize(12 * d);
        }

        void stopAnim() {
            if (anim != null) anim.cancel();
            anim = null;
        }

        void animateTo(float target, Runnable done) {
            stopAnim();
            expanded = target > 0f;
            anim = ValueAnimator.ofFloat(fraction, target);
            anim.setDuration(280);
            anim.setInterpolator(new DecelerateInterpolator());
            anim.addUpdateListener(a -> {
                fraction = (float) a.getAnimatedValue();
                invalidate();
            });
            anim.addListener(new android.animation.AnimatorListenerAdapter() {
                private boolean cancelled;

                @Override
                public void onAnimationCancel(android.animation.Animator a) {
                    cancelled = true;
                }

                @Override
                public void onAnimationEnd(android.animation.Animator a) {
                    if (!cancelled && done != null) done.run();
                }
            });
            anim.start();
        }

        @Override
        protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            float f = fraction;
            float w = w0 + (w1 - w0) * f;
            float h = h0 + (h1 - h0) * f;
            float left = (getWidth() - w) / 2f;
            rect.set(left, 1, left + w, 1 + h);
            float r = h / 2f;
            canvas.drawRoundRect(rect, r, r, pill);
            ring.setColor(accent);
            ring.setAlpha((int) (90 + 120 * f));
            canvas.drawRoundRect(rect, r, r, ring);
            Content ct = content;
            if (ct == null || f < 0.6f) return;
            int alpha = (int) (255 * Math.min(1f, (f - 0.6f) / 0.4f));
            float pad = h * 0.18f;
            float iconSize = h - 2 * pad;
            float x = rect.left + pad + r * 0.25f;
            float cy = rect.centerY();
            if (ct.level >= 0) {
                // Pil simgesi: gövde + uç, doluluk yeşil.
                float bw = iconSize * 0.9f, bh = iconSize * 0.5f;
                RectF body = new RectF(x, cy - bh / 2, x + bw, cy + bh / 2);
                ring.setColor(Color.WHITE);
                ring.setAlpha(alpha);
                canvas.drawRoundRect(body, bh * 0.2f, bh * 0.2f, ring);
                fill.setColor(0xFF68D391);
                fill.setAlpha(alpha);
                float inset = bh * 0.15f;
                canvas.drawRoundRect(new RectF(body.left + inset, body.top + inset,
                    body.left + inset + (bw - 2 * inset) * ct.level / 100f, body.bottom - inset), bh * 0.1f, bh * 0.1f, fill);
                canvas.drawRect(body.right, cy - bh * 0.18f, body.right + bh * 0.15f, cy + bh * 0.18f, fill);
            } else if (ct.icon != null) {
                int s = Math.round(iconSize);
                int ix = Math.round(x), iy = Math.round(cy - iconSize / 2);
                ct.icon.setBounds(ix, iy, ix + s, iy + s);
                ct.icon.setAlpha(alpha);
                ct.icon.draw(canvas);
            }
            float tx = x + iconSize + pad;
            float avail = rect.right - r * 0.5f - tx;
            if (avail <= 0) return;
            title.setAlpha(alpha);
            sub.setAlpha(alpha);
            String t1 = TextUtils.ellipsize(ct.label, title, avail, TextUtils.TruncateAt.END).toString();
            if (ct.sub == null || ct.sub.isEmpty()) {
                canvas.drawText(t1, tx, cy - (title.descent() + title.ascent()) / 2, title);
            } else {
                String t2 = TextUtils.ellipsize(ct.sub, sub, avail, TextUtils.TruncateAt.END).toString();
                canvas.drawText(t1, tx, cy - 2, title);
                canvas.drawText(t2, tx, cy + sub.getTextSize(), sub);
            }
        }
    }
}
