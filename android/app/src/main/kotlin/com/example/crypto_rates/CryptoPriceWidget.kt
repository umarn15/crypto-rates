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

        when (intent.action) {
            AppWidgetManager.ACTION_APPWIDGET_UPDATE -> {
                // Only update data if it's from the refresh button
                if (intent.hasExtra("fromRefreshButton")) {
                    val appWidgetManager = AppWidgetManager.getInstance(context)
                    val thisWidget = ComponentName(context, CryptoPriceWidget::class.java)
                    val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
                    onUpdate(context, appWidgetManager, appWidgetIds)
                }
            }
            "OPEN_APP" -> {
                // Launch app
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                launchIntent?.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                context.startActivity(launchIntent)
            }
        }
    }
}

private fun updateAppWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int
) {
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
        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        putExtra("fromRefreshButton", true)
        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
    }
    val refreshPendingIntent = PendingIntent.getBroadcast(
        context,
        appWidgetId,
        refreshIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    views.setOnClickPendingIntent(R.id.refresh_button, refreshPendingIntent)

    try {
        // Try to get data from both possible SharedPreferences locations
        var cryptoDataString: String? = null

        // Try FlutterSharedPreferences first
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        cryptoDataString = flutterPrefs.getString("flutter.crypto_data", null)
        Log.d(TAG, "Data from FlutterSharedPreferences: $cryptoDataString")

        // If not found, try regular SharedPreferences
        if (cryptoDataString == null) {
            val prefs = context.getSharedPreferences("crypto_widget_prefs", Context.MODE_PRIVATE)
            cryptoDataString = prefs.getString("crypto_data", null)
            Log.d(TAG, "Data from regular SharedPreferences: $cryptoDataString")
        }

        if (cryptoDataString != null) {
            val cryptoData = JSONArray(cryptoDataString)

            if (cryptoData.length() >= 3) {
                // Update first cryptocurrency
                val coin1 = cryptoData.getJSONObject(0)
                views.setTextViewText(R.id.symbol1, coin1.getString("symbol"))
                views.setTextViewText(R.id.price1, "$${coin1.getString("price")}")
                val change1 = coin1.getString("change").toDouble()
                views.setTextViewText(R.id.change1, "${if (change1 >= 0) "+" else ""}${change1}%")
                views.setTextColor(R.id.change1, if (change1 >= 0) Color.GREEN else Color.RED)
                Log.d(TAG, "Updated coin1: ${coin1.getString("symbol")} - $${coin1.getString("price")}")

                // Update second cryptocurrency
                val coin2 = cryptoData.getJSONObject(1)
                views.setTextViewText(R.id.symbol2, coin2.getString("symbol"))
                views.setTextViewText(R.id.price2, "$${coin2.getString("price")}")
                val change2 = coin2.getString("change").toDouble()
                views.setTextViewText(R.id.change2, "${if (change2 >= 0) "+" else ""}${change2}%")
                views.setTextColor(R.id.change2, if (change2 >= 0) Color.GREEN else Color.RED)
                Log.d(TAG, "Updated coin2: ${coin2.getString("symbol")} - $${coin2.getString("price")}")

                // Update third cryptocurrency
                val coin3 = cryptoData.getJSONObject(2)
                views.setTextViewText(R.id.symbol3, coin3.getString("symbol"))
                views.setTextViewText(R.id.price3, "$${coin3.getString("price")}")
                val change3 = coin3.getString("change").toDouble()
                views.setTextViewText(R.id.change3, "${if (change3 >= 0) "+" else ""}${change3}%")
                views.setTextColor(R.id.change3, if (change3 >= 0) Color.GREEN else Color.RED)
                Log.d(TAG, "Updated coin3: ${coin3.getString("symbol")} - $${coin3.getString("price")}")
            } else {
                Log.d(TAG, "Insufficient data: ${cryptoData.length()} coins")
                setErrorState(views, "Insufficient", "data", "available")
            }
        } else {
            Log.d(TAG, "No crypto data found in any preferences")
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