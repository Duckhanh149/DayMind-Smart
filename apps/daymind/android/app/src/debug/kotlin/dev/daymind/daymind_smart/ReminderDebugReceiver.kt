package dev.daymind.daymind_smart

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Base64
import org.json.JSONObject
import java.util.Calendar

/** CI fixture endpoint. Registered only in the debug manifest; excluded from release APKs. */
class ReminderDebugReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context,intent: Intent) {
        val pending=goAsync()
        ReminderRuntime.executor.execute {
            val answer=JSONObject()
            try {
                ReminderRuntime.database(context)?.use { db ->
                    answer.put("ready",true)
                    val command=intent.getStringExtra("command") ?: "ready"
                    val fixture=intent.getStringExtra("fixture") ?: "cold"
                    require(fixture in listOf("cold","edited","quiet","past"))
                    val key="device-smoke-$fixture";val now=System.currentTimeMillis()
                    if(command=="seed") {
                        val delay=if(fixture=="past")-60000L else 20000L
                        val settings=JSONObject().put("preset","normal").put("primaryDevice",true).put("quietEnabled",fixture=="quiet").put("groupingMinutes",10)
                        val minute=Calendar.getInstance().let { it.get(Calendar.HOUR_OF_DAY)*60+it.get(Calendar.MINUTE) }
                        settings.put("quietStart",minute).put("quietEnd",(minute+30)%1440)
                        db.beginTransaction()
                        try {
                            db.execSQL("INSERT OR REPLACE INTO extension_records(area,id,value,updated_ms) VALUES('notifications','settings',?,?)",arrayOf(settings.toString(),now))
                            db.execSQL("INSERT OR REPLACE INTO tasks(id,title,description,priority,status,created_at,updated_at,revision) VALUES(?,?,'',1,0,?,?,1)",arrayOf(key,"DayMind device smoke $fixture",now/1000,now/1000))
                            db.execSQL("INSERT OR REPLACE INTO reminder_events(event_key,task_id,rule_id,task_revision,scheduled_ms,expires_ms,state,read,title,priority,updated_ms) VALUES(?,?,'default',1,?,?,'scheduled',0,?,1,?)",arrayOf(key,key,now+delay,now+900000,"DayMind device smoke $fixture",now))
                            if(fixture=="edited")db.execSQL("UPDATE tasks SET revision=2 WHERE id=?",arrayOf(key))
                            db.setTransactionSuccessful()
                        } finally { db.endTransaction() }
                        db.rawQuery("SELECT platform_id FROM reminder_events WHERE event_key=?",arrayOf(key)).use { it.moveToFirst();ReminderRuntime.arm(context,it.getInt(0),key,now+delay) }
                    } else if(command=="recover") {
                        ReminderRuntime.recover(context,true)
                    } else require(command in listOf("ready","status"))
                    db.rawQuery("SELECT state FROM reminder_events WHERE event_key=?",arrayOf(key)).use { if(it.moveToFirst())answer.put("state",it.getString(0)) }
                    answer.put("notifications",context.getSystemService(NotificationManager::class.java).activeNotifications.size)
                    answer.put("foreground",MainActivity.foreground)
                } ?: answer.put("ready",false)
            } catch(error:Exception){answer.put("error",error.javaClass.simpleName)}
            pending.resultData=Base64.encodeToString(answer.toString().toByteArray(),Base64.NO_WRAP)
            pending.finish()
        }
    }
}
