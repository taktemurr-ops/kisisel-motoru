package com.gamestudio100.kisisel_motoru;

import android.app.WallpaperManager;
import android.appwidget.AppWidgetManager;
import android.content.ActivityNotFoundException;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;


import org.json.JSONObject;

import java.util.List;
import java.util.Map;

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
        String flat = Settings.Secure.getString(context.getContentResolver(), "enabled_notification_listeners");
        if (flat == null || flat.isEmpty()) return false;
        ComponentName me = new ComponentName(context, EdgeNotificationService.class);
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
                    enableComponent(EdgeNotificationService.class);
                    result.success(start(new Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"))
                        || start(new Intent(Settings.ACTION_SETTINGS)));
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
                    enableComponent(Boolean.TRUE.equals(chargeArg) ? ChargeDreamService.class : ClockDreamService.class);
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
