package com.example.crypto_rates

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import org.json.JSONArray
import android.graphics.Color

class CryptoPriceWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }
}

private fun updateAppWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int
) {
    val views = RemoteViews(context.packageName, R.layout.crypto_price_widget)

    try {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val cryptoDataString = prefs.getString("crypto_data", null)

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

                // Update second cryptocurrency
                val coin2 = cryptoData.getJSONObject(1)
                views.setTextViewText(R.id.symbol2, coin2.getString("symbol"))
                views.setTextViewText(R.id.price2, "$${coin2.getString("price")}")
                val change2 = coin2.getString("change").toDouble()
                views.setTextViewText(R.id.change2, "${if (change2 >= 0) "+" else ""}${change2}%")
                views.setTextColor(R.id.change2, if (change2 >= 0) Color.GREEN else Color.RED)

                // Update third cryptocurrency
                val coin3 = cryptoData.getJSONObject(2)
                views.setTextViewText(R.id.symbol3, coin3.getString("symbol"))
                views.setTextViewText(R.id.price3, "$${coin3.getString("price")}")
                val change3 = coin3.getString("change").toDouble()
                views.setTextViewText(R.id.change3, "${if (change3 >= 0) "+" else ""}${change3}%")
                views.setTextColor(R.id.change3, if (change3 >= 0) Color.GREEN else Color.RED)
            }
        }
    } catch (e: Exception) {
        e.printStackTrace()
    }

    appWidgetManager.updateAppWidget(appWidgetId, views)
}