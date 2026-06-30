package com.driverpos.golf_pos_app

import android.os.Build
import android.os.Bundle
import androidx.activity.result.ActivityResult
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

import com.denovo.app.invokeiposgo.launcher.IntentApplication
import com.denovo.app.invokeiposgo.interfaces.TerminalAddListener

import com.denovo.app.invokekozen.scanner.IScannerResult
import com.denovo.app.invokekozen.scanner.ScannerActivity as PeripheralScanner

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.driverpos.golf_pos_app/payment"
    private val SCAN_TIMEOUT = 30000

    private lateinit var activityResultLauncher: ActivityResultLauncher<android.content.Intent>
    private lateinit var intentApplication: IntentApplication
    private lateinit var scannerActivity: PeripheralScanner

    private var pendingResult: MethodChannel.Result? = null
    private var pendingScanResult: MethodChannel.Result? = null
    private var isDirectTransaction = false

    private val iscanResult = object : IScannerResult {
        override fun onSuccess(result: String) {
            runOnUiThread {
                pendingScanResult?.success(result)
                pendingScanResult = null
            }
        }
        override fun onFailure(errorMessage: String) {
            runOnUiThread {
                pendingScanResult?.error("SCAN_FAILED", errorMessage, null)
                pendingScanResult = null
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        activityResultLauncher = registerForActivityResult(
            ActivityResultContracts.StartActivityForResult()
        ) { result: ActivityResult ->
            if (isDirectTransaction) {
                isDirectTransaction = false
                handleDirectTransactionResult(result)
            } else {
                intentApplication.handleResultCallBack(result)
            }
        }

        intentApplication = IntentApplication(this)

        scannerActivity = if (Build.MODEL == "P18") {
            PeripheralScanner(this, iscanResult, SCAN_TIMEOUT)
        } else {
            PeripheralScanner(iscanResult, SCAN_TIMEOUT)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "registerTerminal" -> {
                        val tpn = call.argument<String>("tpn") ?: ""
                        registerTerminal(tpn, result)
                    }
                    "performSale" -> {
                        val args = call.arguments as Map<*, *>
                        performSale(args, result)
                    }
                    "startScan" -> {
                        pendingScanResult = result
                        scannerActivity.startScan()
                    }
                    "stopScan" -> {
                        scannerActivity.stopScan()
                        pendingScanResult?.error("SCAN_CANCELLED", "Scan cancelled", null)
                        pendingScanResult = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun registerTerminal(tpn: String, result: MethodChannel.Result) {
        pendingResult = result

        val req = JSONObject().apply {
            put("tpn", tpn)
            put("applicationType", "DVPAYLITE")
        }

        intentApplication.setTerminalAddListener(object : TerminalAddListener {
            override fun onApplicationLaunched(response: JSONObject?) {}

            override fun onApplicationLaunchFailed(error: JSONObject?) {
                pendingResult?.error("LAUNCH_FAILED", error?.toString(), null)
                pendingResult = null
            }

            override fun onTerminalAdded(response: JSONObject?) {
                pendingResult?.success(jsonToMap(response))
                pendingResult = null
            }

            override fun onTerminalAddFailed(error: JSONObject?) {
                pendingResult?.error("REGISTER_FAILED", error?.toString(), null)
                pendingResult = null
            }
        })

        intentApplication.addTerminal(req, activityResultLauncher)
    }

    private fun performSale(args: Map<*, *>, result: MethodChannel.Result) {
        pendingResult = result

        val req = JSONObject().apply {
            put("tpn",                       args["tpn"] ?: "")
            put("applicationType",           "DVPAYLITE")
            put("type",                      "SALE")
            put("paymentType",               args["paymentType"] ?: "CREDIT")
            put("amount",                    args["amount"] ?: "0.00")
            put("tip",                       args["tip"] ?: "0.00")
            put("refId",                     args["refId"] ?: "")
            put("receiptType",               args["receiptType"] ?: "No")
            put("isTxnStatusScreenRequired", args["isTxnStatusScreenRequired"] ?: "Yes")
            put("showBreakupScreen",         args["showBreakupScreen"] ?: "No")
            put("showTipScreen",             args["showTipScreen"] ?: "No")
            put("showDualPriceScreen",       args["showDualPriceScreen"] ?: "No")

            @Suppress("UNCHECKED_CAST")
            val customUiMap = args["customUI"] as? Map<String, Any?>
            if (customUiMap != null) {
                val customUI = JSONObject()
                customUiMap.forEach { (k, v) -> if (v != null) customUI.put(k, v.toString()) }
                put("customUI", customUI)
            }
        }

        // Launch intent directly so customUI is preserved in the raw JSON.
        // The SDK wrapper (TransactionData) does not have a customUI field and would
        // silently drop it — bypassing it here lets DVPayLite receive the full payload.
        val jsonStr = req.toString()
        android.util.Log.d("DVPayLite_DEBUG", "Sending JSON: $jsonStr")

        val intent = android.content.Intent("ACTION_PERFORM_TRANSACTION").apply {
            component = android.content.ComponentName(
                "com.denovo.app.denovopay",
                "com.denovo.app.denovopay.uilayer.intent_catcher.UIIntentCatcherActivity"
            )
            putExtra("TRANS_DATA", jsonStr)
        }
        isDirectTransaction = true
        activityResultLauncher.launch(intent)
    }

    private fun handleDirectTransactionResult(result: ActivityResult) {
        val transResultStr = result.data?.getStringExtra("TRANS_RESULT")
        if (transResultStr == null) {
            pendingResult?.error("TXN_CANCELLED", "Transaction cancelled", null)
            pendingResult = null
            return
        }
        try {
            val json = JSONObject(transResultStr)
            pendingResult?.success(jsonToMap(json))
        } catch (e: Exception) {
            pendingResult?.error("TXN_FAILED", e.message, null)
        }
        pendingResult = null
    }

    private fun jsonToMap(obj: JSONObject?): Map<String, Any?> {
        if (obj == null) return emptyMap()
        return obj.keys().asSequence().associateWith { key ->
            when (val v = obj.get(key)) {
                JSONObject.NULL -> null
                else -> v.toString()
            }
        }
    }
}
