package com.gamestudio100.kisisel_motoru;

import android.app.Notification;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;

/**
 * Gelen aramada flaş için bildirim dinleyicisi.
 *
 * Play politikası / en az yetki: arama, sistemin (arama uygulamasının)
 * "gelen arama" bildiriminden algılanır (kategori CATEGORY_CALL). Bu sayede
 * READ_PHONE_STATE, READ_CALL_LOG, READ_CONTACTS ya da ANSWER_PHONE_CALLS
 * izinleri İSTENMEZ; arayanın numarası, adı ya da bildirimin metni OKUNMAZ.
 * Fener kamera açılmadan (CameraManager.setTorchMode, izin gerektirmez) yakılır.
 * Kullanıcı "Bildirim erişimi"ni sistem ayarlarından kendisi açar.
 */
public class CallFlashService extends NotificationListenerService {
    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        if (sbn == null) return;
        Notification n = sbn.getNotification();
        if (n == null || !Notification.CATEGORY_CALL.equals(n.category)) return;
        if (!CallFlasher.prefs(getApplicationContext()).optBoolean("enabled", false)) return;
        if (CallFlasher.isRinging(getApplicationContext(), n)) {
            CallFlasher.start(getApplicationContext(), sbn.getKey(), 60000, false);
        } else {
            // Aynı bildirim "görüşme sürüyor"a dönüştü: arama açıldı.
            CallFlasher.stopIfKey(sbn.getKey());
        }
    }

    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        if (sbn != null) CallFlasher.stopIfKey(sbn.getKey());
    }

    @Override
    public void onListenerDisconnected() {
        CallFlasher.stop();
        super.onListenerDisconnected();
    }
}
