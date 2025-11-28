// android/app/src/main/kotlin/com/ashrafhamda/so7ba/MyFirebaseMessagingService.kt
package com.ashrafhamda.so7ba

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.analytics.ktx.analytics
import com.google.firebase.ktx.Firebase

class MyFirebaseMessagingService : FirebaseMessagingService() {
    private val channelId = "so7ba_notifications"
    private val channelName = "So7ba Notifications"

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // Print the token to the console
        println("FCM Token: $token")
        // Here you should send this token to your server
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        // Initialize Firebase Analytics
        val firebaseAnalytics = Firebase.analytics

        // Set user property for notification conversion funnel
        firebaseAnalytics.setUserProperty("notification_received", "true")

        // Always forward to Flutter for handling
        // This ensures the Dart NotificationService can process the message
        println("Forwarding message to Flutter: ${remoteMessage.data}")
        
        // Log notification data event
        val params = Bundle().apply {
            remoteMessage.notification?.title?.let { putString("title", it) }
            remoteMessage.notification?.body?.let { putString("body", it) }
            putString("message_id", remoteMessage.messageId)
            putString("from", remoteMessage.from)
        }
        firebaseAnalytics.logEvent("notification_data", params)
        
        // Print message details for debugging
        println("Received message:")
        println("Title: ${remoteMessage.notification?.title}")
        println("Body: ${remoteMessage.notification?.body}")
        println("Data: ${remoteMessage.data}")
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                // إنشاء قناة الإشعارات مع معرف فريد واسم
                val channel = NotificationChannel(
                    "so7ba_channel_id",  // معرف فريد للقناة
                    "إشعارات صحبة",      // اسم يظهر للمستخدم
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "قناة إشعارات تطبيق صحبة للرسائل المهمة"
                    enableVibration(true)
                    enableLights(true)
                    lightColor = android.graphics.Color.GREEN
                    vibrationPattern = longArrayOf(100, 200, 300, 400, 500)
                }

                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                
                // حذف القناة القديمة إذا كانت موجودة
                notificationManager.deleteNotificationChannel("so7ba_channel_id")
                
                // إنشاء القناة الجديدة
                notificationManager.createNotificationChannel(channel)
            } catch (e: Exception) {
                // طباعة رسالة الخطأ لتصحيح المشكلة
                e.printStackTrace()
            }
        }
    }

    private fun showNotification(title: String, message: String) {
        try {
            val notificationBuilder = NotificationCompat.Builder(this, "so7ba_channel_id")
                .setContentTitle(title)
                .setContentText(message)
                .setSmallIcon(R.drawable.ic_notification)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                .setAutoCancel(true)
                .setTimeoutAfter(3000) // 3 ثواني كحد أقصى للتأخير
                .setDefaults(NotificationCompat.DEFAULT_SOUND or NotificationCompat.DEFAULT_VIBRATE)
                .setVibrate(longArrayOf(100, 200, 300, 400, 500))

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(System.currentTimeMillis().toInt(), notificationBuilder.build())
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}