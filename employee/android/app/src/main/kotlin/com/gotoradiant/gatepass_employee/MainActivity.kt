package com.gotoradiant.gatepass_employee

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.nfc.NfcAdapter
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var foreground = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gatepass/device")
            .setMethodCallHandler { call, result ->
                val adapter = NfcAdapter.getDefaultAdapter(this)
                val hce = packageManager.hasSystemFeature(
                    PackageManager.FEATURE_NFC_HOST_CARD_EMULATION
                )
                when (call.method) {
                    "nfcCapability" -> result.success(
                        mapOf("nfc" to (adapter != null), "enabled" to (adapter?.isEnabled == true), "hce" to hce)
                    )
                    "openNfcSettings" -> {
                        try {
                            openNfcSettings()
                            result.success(null)
                        } catch (_: ActivityNotFoundException) {
                            result.error("nfc_settings_unavailable", null, null)
                        }
                    }
                    "armNfc" -> {
                        val credential = call.arguments as? String
                        if (!foreground || !hce || adapter?.isEnabled != true ||
                            credential == null || !credential.matches(Regex("[0-9a-f]{64}"))
                        ) {
                            result.success(false)
                        } else {
                            NfcPassState.arm(credential.chunked(2).map { it.toInt(16).toByte() }.toByteArray())
                            result.success(true)
                        }
                    }
                    "nfcPassStatus" -> result.success(NfcPassState.status())
                    "disarmNfc" -> {
                        NfcPassState.clear()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun openNfcSettings() {
        try {
            startActivity(Intent(Settings.ACTION_NFC_SETTINGS))
        } catch (_: ActivityNotFoundException) {
            startActivity(Intent(Settings.ACTION_WIRELESS_SETTINGS))
        }
    }

    override fun onResume() {
        super.onResume()
        foreground = true
    }

    override fun onPause() {
        foreground = false
        NfcPassState.clear()
        super.onPause()
    }
}
