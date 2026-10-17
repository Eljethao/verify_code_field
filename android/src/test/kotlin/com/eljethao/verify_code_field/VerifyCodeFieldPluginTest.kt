package com.eljethao.verify_code_field

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

/*
 * Run with `./gradlew :verify_code_field:testDebugUnitTest` in `example/android/`
 * (after building the example app once).
 */
internal class VerifyCodeFieldPluginTest {
    @Test
    fun onMethodCall_unknownMethod_isNotImplemented() {
        val result: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        VerifyCodeFieldPlugin().onMethodCall(MethodCall("unknown", null), result)
        Mockito.verify(result).notImplemented()
    }

    @Test
    fun onMethodCall_stopWithNothingPending_succeeds() {
        val result: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        VerifyCodeFieldPlugin().onMethodCall(MethodCall("stop", null), result)
        Mockito.verify(result).success(null)
    }

    @Test
    fun onMethodCall_startUserConsentWithoutActivity_reportsError() {
        val result: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        VerifyCodeFieldPlugin().onMethodCall(MethodCall("startUserConsent", mapOf("sender" to null)), result)
        Mockito.verify(result).error(Mockito.eq("no_activity"), Mockito.anyString(), Mockito.isNull())
    }
}
