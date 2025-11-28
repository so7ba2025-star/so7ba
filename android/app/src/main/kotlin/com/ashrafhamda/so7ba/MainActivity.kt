package com.ashrafhamda.so7ba

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import android.util.Log
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "so7ba/notifications"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Initialize Firebase
        FirebaseApp.initializeApp(this)
        
        // Get FCM token
        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            if (!task.isSuccessful) {
                Log.w("FCM", "Fetching FCM registration token failed", task.exception)
                return@addOnCompleteListener
            }
            
            // Get new FCM registration token
            val token = task.result
            Log.d("FCM", "FCM Token: $token")
            
            // You can send this token to your server here
        }
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "so7ba/whatsapp_share").setMethodCallHandler { call, result ->
            if (call.method == "share") {
                val text = call.argument<String>("text") ?: ""
                val imagePath = call.argument<String>("imagePath") ?: ""
                try {
                    val file = File(imagePath)
                    val uri: Uri = FileProvider.getUriForFile(
                        this,
                        applicationContext.packageName + ".fileprovider",
                        file
                    )

                    val packages = listOf("com.whatsapp", "com.whatsapp.w4b")
                    var launched = false
                    for (pkg in packages) {
                        val intent = Intent(Intent.ACTION_SEND)
                        intent.type = "image/*"
                        intent.setPackage(pkg)
                        intent.putExtra(Intent.EXTRA_STREAM, uri)
                        intent.putExtra(Intent.EXTRA_TEXT, text)
                        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        try {
                            grantUriPermission(pkg, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        } catch (_: Exception) {}

                        if (intent.resolveActivity(packageManager) != null) {
                            startActivity(intent)
                            launched = true
                            break
                        }
                    }
                    if (launched) {
                        result.success(null)
                    } else {
                        result.error("NO_APP", "WhatsApp not installed", null)
                    }
                } catch (e: Exception) {
                    result.error("SHARE_ERR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
