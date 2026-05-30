package com.example.smart_elec

import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.zing.zalo.zalosdk.oauth.ZaloSDK
import com.zing.zalo.zalosdk.oauth.LoginVia
import com.zing.zalo.zalosdk.oauth.OAuthCompleteListener
import com.zing.zalo.zalosdk.oauth.OauthResponse
import com.zing.zalo.zalosdk.oauth.ZaloOpenAPICallback
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.smartelec/zalo"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "authenticate" -> {
                    val codeChallenge = call.argument<String>("codeChallenge") ?: ""
                    ZaloSDK.Instance.authenticateZaloWithAuthenType(
                        this,
                        LoginVia.APP_OR_WEB,
                        codeChallenge,
                        object : OAuthCompleteListener() {
                            override fun onGetOAuthComplete(response: OauthResponse?) {
                                if (response != null && response.oauthCode != null) {
                                    result.success(response.oauthCode)
                                } else {
                                    result.error("AUTH_ERROR", "Login failed or was cancelled", null)
                                }
                            }
                        }
                    )
                }
                "getAccessToken" -> {
                    val oauthCode = call.argument<String>("oauthCode") ?: ""
                    val codeVerifier = call.argument<String>("codeVerifier") ?: ""
                    Thread {
                        ZaloSDK.Instance.getAccessTokenByOAuthCode(this@MainActivity, oauthCode, codeVerifier, object : ZaloOpenAPICallback {
                            override fun onResult(data: JSONObject?) {
                                Handler(Looper.getMainLooper()).post {
                                    if (data != null && data.optInt("error") == 0) {
                                        result.success(data.toString())
                                    } else {
                                        result.error("TOKEN_ERROR", data?.toString() ?: "Failed to get token", null)
                                    }
                                }
                            }
                        })
                    }.start()
                }
                "getProfile" -> {
                    val accessToken = call.argument<String>("accessToken") ?: ""
                    Thread {
                        ZaloSDK.Instance.getProfile(this@MainActivity, accessToken, object : ZaloOpenAPICallback {
                            override fun onResult(data: JSONObject?) {
                                Handler(Looper.getMainLooper()).post {
                                    result.success(data?.toString())
                                }
                            }
                        }, arrayOf("id", "name", "picture"))
                    }.start()
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        ZaloSDK.Instance.onActivityResult(this, requestCode, resultCode, data)
    }
}
