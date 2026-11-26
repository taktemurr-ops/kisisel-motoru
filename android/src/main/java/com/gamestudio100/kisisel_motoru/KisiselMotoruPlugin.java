package com.gamestudio100.kisisel_motoru;

import android.app.WallpaperManager;
import android.appwidget.AppWidgetManager;
import android.content.ActivityNotFoundException;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.content.pm.ShortcutInfo;
import android.content.pm.ShortcutManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.drawable.Icon;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;


import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/** Flutter köprüsü: kisisel_motoru/native (lib/src/platform/native.dart). */
public class KisiselMotoruPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private MethodChannel channel;
    private Context context;

    static final Class<?>[] WIDGETS = {
        ClockWidget.class, DateWidget.class, CountdownWidget.class, NoteWidget.class, BatteryWidget.class
    };

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "kisisel_motoru/native");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        channel = null;
    }

    private void enableComponent(Class<?> cls) {
        context.getPackageManager().setComponentEnabledSetting(
            new ComponentName(context, cls),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP);
    }

    private boolean start(Intent i) {
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try {
            context.startActivity(i);
            return true;
        } catch (ActivityNotFoundException | SecurityException e) {
            return false;
        }
    }

    /** Kullanıcı bildirim erişimini bu uygulamanın dinleyicisine vermiş mi. */
    private boolean listenerGranted() {
        return listenerGranted(EdgeNotificationService.class);
    }

    /** Özellikle ilgili bildirim dinleyicisi (kenar, ada, arama). */
    private static Class<?> listenerClass(String feature) {
        if ("island".equals(feature)) return IslandNotificationService.class;
        if ("call".equals(feature)) return CallFlashService.class;
        return EdgeNotificationService.class;
    }

    private boolean listenerGranted(Class<?> cls) {
        String flat = Settings.Secure.getString(context.getContentResolver(), "enabled_notification_listeners");
        if (flat == null || flat.isEmpty()) return false;
        ComponentName me = new ComponentName(context, cls);
        for (String part : flat.split(":")) {
            ComponentName cn = ComponentName.unflattenFromString(part);
            if (me.equals(cn)) return true;
        }
        return false;
    }

    private static Class<?> widgetClass(String type) {
        switch (type == null ? "" : type) {
            case "clock": return ClockWidget.class;
            case "date": return DateWidget.class;
            case "countdown": return CountdownWidget.class;
            case "note": return NoteWidget.class;
            case "battery": return BatteryWidget.class;
            default: return null;
        }
    }

    /**
     * Başlatıcıda görünen uygulamalar (ad, paket, kategori). Android 11+ paket
     * görünürlüğü manifestteki <queries> LAUNCHER sorgusuyla sağlanır;
     * QUERY_ALL_PACKAGES İSTENMEZ (Play politikası). Liste cihazdan çıkmaz.
     */
    private List<Map<String, Object>> listApps() {
        PackageManager pm = context.getPackageManager();
        Intent i = new Intent(Intent.ACTION_MAIN);
        i.addCategory(Intent.CATEGORY_LAUNCHER);
        List<ResolveInfo> found = pm.queryIntentActivities(i, 0);
        List<Map<String, Object>> out = new ArrayList<>();
        Set<String> seen = new HashSet<>();
        for (ResolveInfo ri : found) {
            if (ri.activityInfo == null) continue;
            String pkg = ri.activityInfo.packageName;
            if (pkg == null || pkg.equals(context.getPackageName()) || !seen.add(pkg)) continue;
            HashMap<String, Object> m = new HashMap<>();
            m.put("label", String.valueOf(ri.loadLabel(pm)));
            m.put("package", pkg);
            int cat = -1;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && ri.activityInfo.applicationInfo != null) {
                cat = ri.activityInfo.applicationInfo.category;
            }
            m.put("category", cat);
            out.add(m);
        }
        Collections.sort(out, (a, b) -> String.valueOf(a.get("label")).compareToIgnoreCase(String.valueOf(b.get("label"))));
        return out;
    }

    /** Seçilen uygulamayı açan, özel simgeli kısayolu sabitleme isteği (Android 8+). */
    private boolean pinShortcut(String pkg, String label, byte[] png) {
        if (pkg == null || png == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false;
        ShortcutManager sm = context.getSystemService(ShortcutManager.class);
        if (sm == null || !sm.isRequestPinShortcutSupported()) return false;
        Intent launch = context.getPackageManager().getLaunchIntentForPackage(pkg);
        if (launch == null) return false;
        launch.setAction(Intent.ACTION_MAIN);
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        Bitmap bmp = BitmapFactory.decodeByteArray(png, 0, png.length);
        if (bmp == null) return false;
        String name = label == null || label.trim().isEmpty() ? pkg : label.trim();
        ShortcutInfo info = new ShortcutInfo.Builder(context, "estetik_" + pkg + "_" + System.currentTimeMillis())
            .setShortLabel(name.length() > 24 ? name.substring(0, 24) : name)
            .setLongLabel(name)
            .setIcon(Icon.createWithBitmap(bmp))
            .setIntent(launch)
            .build();
        return sm.requestPinShortcut(info, null);
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        try {
            switch (call.method) {
                case "enable": {
                    String f = call.argument("feature");
                    if ("wallpaper".equals(f)) enableComponent(SceneWallpaperService.class);
                    else if ("dream".equals(f)) enableComponent(ClockDreamService.class);
                    else if ("chargeDream".equals(f)) enableComponent(ChargeDreamService.class);
                    else if ("edge".equals(f)) enableComponent(EdgeNotificationService.class);
                    else if ("island".equals(f)) enableComponent(IslandNotificationService.class);
                    else if ("call".equals(f)) enableComponent(CallFlashService.class);
                    else if ("aod".equals(f)) enableComponent(AodDreamService.class);
                    else if ("widgets".equals(f)) for (Class<?> c : WIDGETS) enableComponent(c);
                    result.success(null);
                    break;
                }
                case "setWallpaper": {
                    String scene = call.argument("scene");
                    List<?> colors = call.argument("colors");
                    Number speed = call.argument("speed");
                    SharedPreferences.Editor e = NativePrefs.get(context).edit();
                    if (scene != null) e.putString("wall_scene", scene);
                    if (colors != null) e.putString("wall_colors", NativePrefs.joinColors(colors));
                    if (speed != null) e.putFloat("wall_speed", speed.floatValue());
                    e.apply();
                    result.success(null);
                    break;
                }
                case "openLiveWallpaper": {
                    enableComponent(SceneWallpaperService.class);
                    Intent i = new Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER);
                    i.putExtra(WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT,
                        new ComponentName(context, SceneWallpaperService.class));
                    boolean ok = start(i) || start(new Intent(WallpaperManager.ACTION_LIVE_WALLPAPER_CHOOSER));
                    result.success(ok);
                    break;
                }
                case "setDream": {
                    Object args = call.arguments;
                    JSONObject j = args instanceof Map ? new JSONObject((Map<?, ?>) args) : new JSONObject();
                    NativePrefs.get(context).edit().putString("dream_json", j.toString()).apply();
                    result.success(null);
                    break;
                }
                case "setCharge":
                case "setEdge": {
                    boolean charge = "setCharge".equals(call.method);
                    Object args = call.arguments;
                    JSONObject j = args instanceof Map ? new JSONObject((Map<?, ?>) args) : new JSONObject();
                    Object colors = args instanceof Map ? ((Map<?, ?>) args).get("colors") : null;
                    SharedPreferences.Editor e = NativePrefs.get(context).edit();
                    e.putString(charge ? "charge_json" : "edge_json", j.toString());
                    if (colors instanceof List) e.putString(charge ? "charge_colors" : "edge_colors", NativePrefs.joinColors((List<?>) colors));
                    e.apply();
                    result.success(null);
                    break;
                }
                case "edgeStatus": {
                    java.util.HashMap<String, Object> m = new java.util.HashMap<>();
                    m.put("listener", listenerGranted());
                    m.put("overlay", EdgeOverlay.canDraw(context));
                    result.success(m);
                    break;
                }
                case "openNotificationAccess": {
                    Class<?> cls = listenerClass(call.argument("feature"));
                    enableComponent(cls);
                    boolean ok = false;
                    if (Build.VERSION.SDK_INT >= 30) {
                        // Android 11+: doğrudan bu dinleyicinin ayrıntı sayfası.
                        Intent i = new Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS);
                        i.putExtra(Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                            new ComponentName(context, cls).flattenToString());
                        ok = start(i);
                    }
                    result.success(ok || start(new Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"))
                        || start(new Intent(Settings.ACTION_SETTINGS)));
                    break;
                }
                case "featureStatus": {
                    HashMap<String, Object> m = new HashMap<>();
                    m.put("listener", listenerGranted(listenerClass(call.argument("feature"))));
                    m.put("overlay", EdgeOverlay.canDraw(context));
                    m.put("torch", CallFlasher.hasFlash(context));
                    result.success(m);
                    break;
                }
                case "setPrefs": {
                    String key = call.argument("key");
                    Map<?, ?> prefs = call.argument("prefs");
                    if (key == null || !(key.equals("island") || key.equals("call") || key.equals("aod"))) {
                        result.success(null);
                        break;
                    }
                    JSONObject j = prefs == null ? new JSONObject() : new JSONObject(prefs);
                    NativePrefs.get(context).edit().putString(key + "_json", j.toString()).apply();
                    if ("island".equals(key)) IslandOverlay.refreshIdle(context);
                    if ("call".equals(key) && !j.optBoolean("enabled", false)) CallFlasher.stop();
                    result.success(null);
                    break;
                }
                case "testIsland": {
                    result.success(IslandOverlay.demo(context, call.argument("text")));
                    break;
                }
                case "testFlash": {
                    Number sec = call.argument("seconds");
                    long ms = (long) (Math.max(1, Math.min(10, sec == null ? 3 : sec.doubleValue())) * 1000);
                    result.success(CallFlasher.start(context, "test", ms, true));
                    break;
                }
                case "nextAlarm": {
                    long t = AodDreamService.nextAlarm(context);
                    result.success(t > 0 ? t : null);
                    break;
                }
                case "listApps": {
                    result.success(listApps());
                    break;
                }
                case "canPinShortcuts": {
                    boolean ok = false;
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        ShortcutManager sm = context.getSystemService(ShortcutManager.class);
                        ok = sm != null && sm.isRequestPinShortcutSupported();
                    }
                    result.success(ok);
                    break;
                }
                case "pinShortcut": {
                    result.success(pinShortcut(call.argument("package"), call.argument("label"), call.argument("png")));
                    break;
                }
                case "openOverlaySettings": {
                    boolean ok = false;
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        ok = start(new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:" + context.getPackageName())))
                            || start(new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION));
                    }
                    result.success(ok);
                    break;
                }
                case "testEdge": {
                    result.success(EdgeOverlay.show(context));
                    break;
                }
                case "openDreamSettings": {
                    Boolean chargeArg = call.argument("charge");
                    Boolean aodArg = call.argument("aod");
                    enableComponent(Boolean.TRUE.equals(aodArg) ? AodDreamService.class
                        : Boolean.TRUE.equals(chargeArg) ? ChargeDreamService.class : ClockDreamService.class);
                    result.success(start(new Intent(Settings.ACTION_DREAM_SETTINGS))
                        || start(new Intent(Settings.ACTION_DISPLAY_SETTINGS)));
                    break;
                }
                case "canPinWidgets": {
                    boolean ok = false;
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        AppWidgetManager m = context.getSystemService(AppWidgetManager.class);
                        ok = m != null && m.isRequestPinAppWidgetSupported();
                    }
                    result.success(ok);
                    break;
                }
                case "pinWidget": {
                    Class<?> cls = widgetClass(call.argument("type"));
                    boolean ok = false;
                    if (cls != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        enableComponent(cls);
                        AppWidgetManager m = context.getSystemService(AppWidgetManager.class);
                        if (m != null && m.isRequestPinAppWidgetSupported()) {
                            ok = m.requestPinAppWidget(new ComponentName(context, cls), null, null);
                        }
                    }
                    result.success(ok);
                    break;
                }
                default:
                    result.notImplemented();
            }
        } catch (RuntimeException e) {
            result.error("native", e.getMessage(), null);
        }
    }
}
