package com.gamestudio100.kisisel_motoru;

import android.app.Notification;
import android.content.Context;
import android.os.PowerManager;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;

/**
 * Kenar ışıklandırma için bildirim dinleyicisi. Yalnızca "yeni bir bildirim
 * geldi" bilgisini kullanır: başlık, metin ya da gönderen OKUNMAZ, saklanmaz,
 * hiçbir yere gönderilmez. Kullanıcı sistem ayarlarından "Bildirim erişimi"ni
 * açınca çalışır; uygulamada "Bildirim gelince kenarları yak" kapalıysa ya da
 * ekran kapalıysa hiçbir şey yapmaz.
 */
public class EdgeNotificationService extends NotificationListenerService {
    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        if (sbn == null) return;
        Context c = getApplicationContext();
        if (!EdgeOverlay.prefs(c).optBoolean("enabled", false)) return;
        if (sbn.isOngoing() || getPackageName().equals(sbn.getPackageName())) return;
        Notification n = sbn.getNotification();
        if (n != null && (n.flags & Notification.FLAG_GROUP_SUMMARY) != 0) return;
        PowerManager pm = (PowerManager) c.getSystemService(Context.POWER_SERVICE);
        if (pm != null && !pm.isInteractive()) return;
        EdgeOverlay.show(c);
    }
}
