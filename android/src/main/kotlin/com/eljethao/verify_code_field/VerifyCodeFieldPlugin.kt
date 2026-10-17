package com.eljethao.verify_code_field

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import android.util.Base64
import androidx.core.content.ContextCompat
import androidx.core.os.BundleCompat
import com.google.android.gms.auth.api.phone.SmsRetriever
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.Status
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.security.MessageDigest

/**
 * Reads a verification code SMS with Google's SMS User Consent API (one tap, any message)
 * or SMS Retriever API (no tap, message must end with the app hash). Needs no SMS permission.
 *
 * Each `start*` call returns the full SMS text when it arrives, or null on timeout (5 minutes),
 * when the user declines, or when it is cancelled by `stop` or a newer `start*` call.
 */
class VerifyCodeFieldPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pending: Result? = null
    private var receiver: BroadcastReceiver? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "verify_code_field")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        finish(null)
        channel.setMethodCallHandler(null)
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "startUserConsent" -> startUserConsent(call.argument<String>("sender"), result)
            "startRetriever" -> startRetriever(result)
            "stop" -> {
                finish(null)
                result.success(null)
            }
            "getAppSignature" -> result.success(context?.let { appSignature(it) })
            else -> result.notImplemented()
        }
    }

    private fun startUserConsent(sender: String?, result: Result) {
        val activity = activity
            ?: return result.error("no_activity", "SMS User Consent needs a foreground activity.", null)
        begin(result)
        SmsRetriever.getClient(activity)
            .startSmsUserConsent(sender)
            .addOnFailureListener { error -> fail("start_failed", error.message) }
    }

    private fun startRetriever(result: Result) {
        val context = context
            ?: return result.error("no_context", "The plugin is not attached.", null)
        begin(result)
        SmsRetriever.getClient(context)
            .startSmsRetriever()
            .addOnFailureListener { error -> fail("start_failed", error.message) }
    }

    /** Cancels any earlier listen (it returns null), then waits for the SMS broadcast. */
    private fun begin(result: Result) {
        finish(null)
        pending = result
        val context = context ?: return
        val smsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) = onSmsBroadcast(intent)
        }
        ContextCompat.registerReceiver(
            context,
            smsReceiver,
            IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION),
            SmsRetriever.SEND_PERMISSION,
            null,
            ContextCompat.RECEIVER_EXPORTED,
        )
        receiver = smsReceiver
    }

    private fun onSmsBroadcast(intent: Intent) {
        if (intent.action != SmsRetriever.SMS_RETRIEVED_ACTION) return
        val extras = intent.extras ?: return
        val status = BundleCompat.getParcelable(extras, SmsRetriever.EXTRA_STATUS, Status::class.java)
        if (status?.statusCode != CommonStatusCodes.SUCCESS) {
            finish(null) // TIMEOUT or another failure.
            return
        }
        val consentIntent = BundleCompat.getParcelable(extras, SmsRetriever.EXTRA_CONSENT_INTENT, Intent::class.java)
        if (consentIntent != null) {
            showConsent(consentIntent)
        } else {
            finish(extras.getString(SmsRetriever.EXTRA_SMS_MESSAGE))
        }
    }

    private fun showConsent(consentIntent: Intent) {
        unregisterReceiver() // One message per session; the dialog result arrives in onActivityResult.
        val activity = activity ?: return finish(null)
        // Only open Google Play services' own consent screen (guards against intent redirection),
        // and never pass on URI permissions.
        val target = consentIntent.resolveActivity(activity.packageManager)
        if (target == null || target.packageName != GMS_PACKAGE) return finish(null)
        consentIntent.removeFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                Intent.FLAG_GRANT_PREFIX_URI_PERMISSION,
        )
        try {
            activity.startActivityForResult(consentIntent, REQUEST_CONSENT)
        } catch (_: ActivityNotFoundException) {
            finish(null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CONSENT) return false
        finish(if (resultCode == Activity.RESULT_OK) data?.getStringExtra(SmsRetriever.EXTRA_SMS_MESSAGE) else null)
        return true
    }

    private fun finish(message: String?) {
        unregisterReceiver()
        val result = pending ?: return
        pending = null
        result.success(message)
    }

    private fun fail(code: String, message: String?) {
        unregisterReceiver()
        val result = pending ?: return
        pending = null
        result.error(code, message ?: "Could not start listening for SMS.", null)
    }

    private fun unregisterReceiver() {
        val smsReceiver = receiver ?: return
        receiver = null
        try {
            context?.unregisterReceiver(smsReceiver)
        } catch (_: IllegalArgumentException) {
            // Already unregistered.
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = detachActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        detachActivity()
        finish(null)
    }

    private fun detachActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
    }

    companion object {
        private const val GMS_PACKAGE = "com.google.android.gms"
        private const val REQUEST_CONSENT = 0x5653 // "VS"

        /**
         * The 11-character hash an SMS must end with for the SMS Retriever API: the first 9 bytes of
         * SHA-256("<package name> <signing certificate>"), Base64-encoded.
         */
        fun appSignature(context: Context): String? {
            val packageName = context.packageName
            val signature = signingCertificate(context) ?: return null
            return hash(packageName, signature.toCharsString())
        }

        internal fun hash(packageName: String, signature: String): String {
            val digest = MessageDigest.getInstance("SHA-256").digest("$packageName $signature".toByteArray(Charsets.UTF_8))
            return Base64.encodeToString(digest.copyOf(9), Base64.NO_PADDING or Base64.NO_WRAP).substring(0, 11)
        }

        private fun signingCertificate(context: Context): Signature? {
            val pm = context.packageManager
            return try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    val info = pm.getPackageInfo(context.packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                    val signing = info.signingInfo ?: return null
                    val signers = if (signing.hasMultipleSigners()) signing.apkContentsSigners else signing.signingCertificateHistory
                    signers?.firstOrNull()
                } else {
                    @Suppress("DEPRECATION")
                    pm.getPackageInfo(context.packageName, PackageManager.GET_SIGNATURES).signatures?.firstOrNull()
                }
            } catch (_: PackageManager.NameNotFoundException) {
                null
            }
        }
    }
}
