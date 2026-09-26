package com.kuwrir.merchant

import android.app.NotificationManager
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// local_auth's biometric prompt requires a FragmentActivity host.
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "cocourir/power"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        try {
                            startActivity(
                                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                                    .setData(Uri.parse("package:$packageName"))
                            )
                        } catch (e: Exception) {
                            // No-op — some OEM builds strip this action; the
                            // autostart-settings fallback below is the
                            // user's remaining path either way.
                        }
                        result.success(null)
                    }
                    "canUseFullScreenIntent" -> {
                        if (Build.VERSION.SDK_INT >= 34) {
                            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                            result.success(nm.canUseFullScreenIntent())
                        } else {
                            result.success(true)
                        }
                    }
                    "requestFullScreenIntentPermission" -> {
                        if (Build.VERSION.SDK_INT >= 34) {
                            try {
                                startActivity(
                                    Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT)
                                        .setData(Uri.parse("package:$packageName"))
                                )
                            } catch (e: Exception) {
                                // No-op.
                            }
                        }
                        result.success(null)
                    }
                    "openAutostartSettings" -> {
                        openAutostartSettingsInternal()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * OEM "autostart"/"protected app" screens have no public API — only
     * component names that vary by manufacturer and OS version and can stop
     * resolving after an update. Try each known candidate for this device's
     * manufacturer and fall back to the app's own App Info page (from which
     * the user can still reach battery/autostart settings manually) the
     * moment nothing resolves.
     */
    private fun openAutostartSettingsInternal() {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val candidates = mutableListOf<Intent>()
        fun candidate(pkg: String, cls: String) {
            candidates.add(Intent().setComponent(ComponentName(pkg, cls)))
        }
        when {
            manufacturer.contains("xiaomi") -> {
                candidate(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity",
                )
            }
            manufacturer.contains("oppo") -> {
                candidate(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.permission.startup.StartupAppListActivity",
                )
                candidate(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.startupapp.StartupAppListActivity",
                )
                candidate(
                    "com.oppo.safe",
                    "com.oppo.safe.permission.startup.StartupAppListActivity",
                )
            }
            manufacturer.contains("vivo") -> {
                candidate(
                    "com.vivo.permissionmanager",
                    "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                )
                candidate(
                    "com.iqoo.secure",
                    "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
                )
            }
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> {
                candidate(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                )
                candidate(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.optimize.process.ProtectActivity",
                )
            }
            manufacturer.contains("samsung") -> {
                candidate(
                    "com.samsung.android.lool",
                    "com.samsung.android.sm.ui.battery.BatteryActivity",
                )
            }
            manufacturer.contains("oneplus") -> {
                candidate(
                    "com.oneplus.security",
                    "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
                )
            }
            manufacturer.contains("letv") || manufacturer.contains("leeco") -> {
                candidate(
                    "com.letv.android.letvsafe",
                    "com.letv.android.letvsafe.AutobootManageActivity",
                )
            }
            manufacturer.contains("asus") -> {
                candidate(
                    "com.asus.mobilemanager",
                    "com.asus.mobilemanager.autostart.AutoStartActivity",
                )
            }
        }

        for (intent in candidates) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return
            } catch (e: Exception) {
                // Component doesn't resolve on this OS build — try the next.
            }
        }

        try {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(Uri.parse("package:$packageName"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        } catch (e: Exception) {
            // Nothing left to try.
        }
    }
}
