package com.anynote.app.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import com.anynote.app.MainActivity
import com.anynote.app.R
import org.json.JSONArray
import org.json.JSONObject

class RecentNotesWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences("anynote_widget_data", Context.MODE_PRIVATE)
        val dataJson = prefs.getString("widget_data", null)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.recent_notes_widget)

            if (dataJson != null) {
                val root = JSONObject(dataJson)
                val notes = root.optJSONArray("recent_notes") ?: JSONArray()

                // Show up to 3 notes
                for (i in 0 until minOf(notes.length(), 3)) {
                    val note = notes.getJSONObject(i)
                    val id = note.getString("id")
                    val title = note.getString("title")

                    val noteViewId = when (i) {
                        0 -> R.id.note_title_1
                        1 -> R.id.note_title_2
                        else -> R.id.note_title_3
                    }

                    views.setTextViewText(noteViewId, title)

                    // Click to open note
                    val intent = Intent(
                        Intent.ACTION_VIEW,
                        Uri.parse("anynote://notes/$id"),
                        context,
                        MainActivity::class.java
                    )
                    val pendingIntent = PendingIntent.getActivity(
                        context, i, intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(noteViewId, pendingIntent)
                }
            } else {
                views.setTextViewText(R.id.note_title_1, "No recent notes")
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(
                ComponentName(context, RecentNotesWidget::class.java)
            )
            onUpdate(context, appWidgetManager, ids)
        }
    }
}
