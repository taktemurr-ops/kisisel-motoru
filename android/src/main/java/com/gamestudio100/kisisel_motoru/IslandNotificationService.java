package com.gamestudio100.kisisel_motoru;

import android.app.KeyguardManager;
import android.app.Notification;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.os.PowerManager;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;

/**
 * Dinamik bildirim adası için bildirim dinleyicisi. Yeni bir bildirim gelince
 * (ekran açık ve kilitsizken) kamera çevresinde birkaç saniye bir hap
 * gösterir: uygulamanın simgesi ve adı; kullanıcı açtıysa bildirimin başlığı.
 * Hiçbir içerik saklanmaz ya da gönderilmez. Şarj takılınca da gösterebilir
 * (dinleyici zaten çalıştığı için ayrı bir arka plan hizmeti gerekmez).
 * Erişilebilirlik hizmeti KULLANILMAZ (Play politikası): ada uygulama kaplama
 * penceresidir ve sistem durum çubuğunun altında kalır.
 */
public class IslandNotificationService extends NotificationListenerService {
    private BroadcastReceiver power;

    @Override
    public void onListenerConnected() {
        super.onListenerConnected();
        if (power != null) return;
        power = new BroadcastReceiver() {
            @Override
            public void onReceive(Context c, Intent i) {
                if (!usable(c)) return;
                if (!IslandOverlay.prefs(c).optBoolean("charging", true)) return;
                IslandOverlay.showCharging(c);
            }
        };
        IntentFilter f = new IntentFilter(Intent.ACTION_POWER_CONNECTED);
        try {
            if (Build.VERSION.SDK_INT >= 33) {
                registerReceiver(power, f, Context.RECEIVER_NOT_EXPORTED);
            } else {
                registerReceiver(power, f);
            }
        } catch (RuntimeException e) {
            power = null;
        }
        IslandOverlay.refreshIdle(getApplicationContext());
    }

    @Override
    public void onListenerDisconnected() {
        if (power != null) {
            try {
                unregisterReceiver(power);
            } catch (RuntimeException ignored) {
            }
            power = null;
        }
        IslandOverlay.hide();
        super.onListenerDisconnected();
    }

    /** Ada açık, ekran açık ve kilitsiz mi. */
    static boolean usable(Context c) {
        if (!IslandOverlay.prefs(c).optBoolean("enabled", false)) return false;
        PowerManager pm = (PowerManager) c.getSystemService(Context.POWER_SERVICE);
        if (pm != null && !pm.isInteractive()) return false;
        KeyguardManager km = (KeyguardManager) c.getSystemService(Context.KEYGUARD_SERVICE);
        return km == null || !km.isKeyguardLocked();
    }

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        if (sbn == null) return;
        Context c = getApplicationContext();
        if (!usable(c)) return;
        if (sbn.isOngoing() || getPackageName().equals(sbn.getPackageName())) return;
        Notification n = sbn.getNotification();
        if (n == null || (n.flags & Notification.FLAG_GROUP_SUMMARY) != 0) return;
        // Gelen arama bildirimleri arama ekranında zaten görünür.
        if (Notification.CATEGORY_CALL.equals(n.category)) return;
        IslandOverlay.showNotification(c, sbn.getPackageName(), n);
    }
}
