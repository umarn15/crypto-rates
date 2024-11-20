package com.example.crypto_rates

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONArray
import android.graphics.Color
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import android.os.Handler
import android.os.Looper

private const val TAG = "CryptoPriceWidget"

class CryptoPriceWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "onUpdate called")
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        Log.d(TAG, "onReceive called with action: ${intent.action}")

        when (intent.action) {
            AppWidgetManager.ACTION_APPWIDGET_UPDATE -> {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val thisWidget = ComponentName(context, CryptoPriceWidget::class.java)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
                onUpdate(context, appWidgetManager, appWidgetIds)
            }
            "REFRESH_ACTION" -> {
                Log.d(TAG, "Refresh action received")
                // Show refreshing state immediately
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val thisWidget = ComponentName(context, CryptoPriceWidget::class.java)
                val views = RemoteViews(context.packageName, R.layout.crypto_price_widget)
                views.setTextViewText(R.id.last_updated, "Refreshing...")
                appWidgetManager.updateAppWidget(thisWidget, views)

                // Create an intent to launch the Flutter activity
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    action = "REFRESH_DATA"
                }
                context.startActivity(launchIntent)

                // Schedule an update after a short delay
                Handler(Looper.getMainLooper()).postDelayed({
                    val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
                    onUpdate(context, appWidgetManager, appWidgetIds)
                }, 2000) // 2 second delay
            }
            "OPEN_APP" -> {
                Log.d(TAG, "Open app action received")
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                launchIntent?.let {
                    it.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    context.startActivity(it)
                }
            }
        }
    }
}

private fun updateAppWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int
) {
    Log.d(TAG, "updateAppWidget called for ID: $appWidgetId")
    val views = RemoteViews(context.packageName, R.layout.crypto_price_widget)

    // Add click intent to open app
    val openAppIntent = Intent(context, CryptoPriceWidget::class.java).apply {
        action = "OPEN_APP"
    }
    val openAppPendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        openAppIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    views.setOnClickPendingIntent(R.id.widget_layout, openAppPendingIntent)

    // Add refresh button click intent
    val refreshIntent = Intent(context, CryptoPriceWidget::class.java).apply {
        action = "REFRESH_ACTION"
    }
    val refreshPendingIntent = PendingIntent.getBroadcast(
        context,
        1,
        refreshIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    views.setOnClickPendingIntent(R.id.refresh_button, refreshPendingIntent)

    try {
        // Try to get data from SharedPreferences
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val cryptoDataString = prefs.getString("flutter.crypto_data", null)
        val lastUpdated = prefs.getString("flutter.last_updated", null)

        Log.d(TAG, "Data from SharedPreferences: $cryptoDataString")
        Log.d(TAG, "Last updated from SharedPreferences: $lastUpdated")

        // Update last updated time
        if (lastUpdated != null) {
            try {
                val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
                val date = dateFormat.parse(lastUpdated.replace("T", " ").substring(0, 19))
                val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
                views.setTextViewText(R.id.last_updated, "Updated: ${timeFormat.format(date)}")
                Log.d(TAG, "Successfully formatted last updated time")
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing date: $e")
                views.setTextViewText(R.id.last_updated, "Last update: unknown")
            }
        } else {
            views.setTextViewText(R.id.last_updated, "Tap to refresh")
        }

        if (cryptoDataString != null) {
            val cryptoData = JSONArray(cryptoDataString)
            Log.d(TAG, "Processing crypto data array of length: ${cryptoData.length()}")

            if (cryptoData.length() >= 3) {
                // Update first cryptocurrency
                val coin1 = cryptoData.getJSONObject(0)
                views.setTextViewText(R.id.symbol1, coin1.getString("symbol"))
                views.setTextViewText(R.id.price1, "$${coin1.getString("price")}")
                val change1 = coin1.getString("change").toDouble()
                views.setTextViewText(R.id.change1, "${if (change1 >= 0) "+" else ""}${change1}%")
                views.setTextColor(R.id.change1, if (change1 >= 0) Color.GREEN else Color.RED)
                Log.d(TAG, "Updated coin1: ${coin1.getString("symbol")}")

                // Update second cryptocurrency
                val coin2 = cryptoData.getJSONObject(1)
                views.setTextViewText(R.id.symbol2, coin2.getString("symbol"))
                views.setTextViewText(R.id.price2, "$${coin2.getString("price")}")
                val change2 = coin2.getString("change").toDouble()
                views.setTextViewText(R.id.change2, "${if (change2 >= 0) "+" else ""}${change2}%")
                views.setTextColor(R.id.change2, if (change2 >= 0) Color.GREEN else Color.RED)
                Log.d(TAG, "Updated coin2: ${coin2.getString("symbol")}")

                // Update third cryptocurrency
                val coin3 = cryptoData.getJSONObject(2)
                views.setTextViewText(R.id.symbol3, coin3.getString("symbol"))
                views.setTextViewText(R.id.price3, "$${coin3.getString("price")}")
                val change3 = coin3.getString("change").toDouble()
                views.setTextViewText(R.id.change3, "${if (change3 >= 0) "+" else ""}${change3}%")
                views.setTextColor(R.id.change3, if (change3 >= 0) Color.GREEN else Color.RED)
                Log.d(TAG, "Updated coin3: ${coin3.getString("symbol")}")
            } else {
                Log.d(TAG, "Insufficient data in crypto array")
                setErrorState(views, "Insufficient", "data", "available")
            }
        } else {
            Log.d(TAG, "No crypto data found")
            setErrorState(views, "No data", "Please open", "the app")
        }
    } catch (e: Exception) {
        Log.e(TAG, "Error updating widget", e)
        setErrorState(views, "Error", "Please check", "logs")
    }

    // Update the widget
    try {
        appWidgetManager.updateAppWidget(appWidgetId, views)
        Log.d(TAG, "Widget successfully updated")
    } catch (e: Exception) {
        Log.e(TAG, "Error in final widget update", e)
    }
}

private fun setErrorState(views: RemoteViews, text1: String, text2: String, text3: String) {
    views.setTextViewText(R.id.symbol1, text1)
    views.setTextViewText(R.id.price1, "")
    views.setTextViewText(R.id.change1, "")

    views.setTextViewText(R.id.symbol2, text2)
    views.setTextViewText(R.id.price2, "")
    views.setTextViewText(R.id.change2, "")

    views.setTextViewText(R.id.symbol3, text3)
    views.setTextViewText(R.id.price3, "")
    views.setTextViewText(R.id.change3, "")
}