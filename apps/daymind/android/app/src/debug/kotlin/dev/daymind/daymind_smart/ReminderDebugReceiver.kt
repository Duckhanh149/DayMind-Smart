package dev.daymind.daymind_smart

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Base64
import org.json.JSONObject
import java.util.Calendar
import java.time.Instant
import java.time.ZoneId
import java.security.MessageDigest

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
                    if(command=="secure") {
                        val store=SecureStore(context)
                        var output:Any?=null
                        val reply=object:io.flutter.plugin.common.MethodChannel.Result {
                            override fun success(value:Any?) { output=value }
                            override fun error(code:String,message:String?,details:Any?) { throw IllegalStateException(code) }
                            override fun notImplemented() { throw IllegalStateException("method") }
                        }
                        fun call(method:String,value:String?=null) {
                            val args=mutableMapOf<String,Any?>("key" to "test_probe")
                            if(value!=null)args["value"]=value
                            store.handle(io.flutter.plugin.common.MethodCall(method,args),reply)
                        }
                        val probe="DayMind native credential probe ă"
                        call("write",probe);call("read");check(output==probe)
                        val encrypted=context.getSharedPreferences("daymind_secure_v1",Context.MODE_PRIVATE).getString("test_probe",null)!!
                        check(!encrypted.contains(probe))
                        call("write",probe+" updated");call("read");check(output==probe+" updated")
                        call("delete");call("read");check(output==null)
                        answer.put("securePassed",true)
                    }
                    val fixture=intent.getStringExtra("fixture") ?: "cold"
                    require(fixture in listOf("cold","edited","quiet","past","digest"))
                    val now=System.currentTimeMillis();val digestAt=(now/60000+1)*60000
                    val digestDate=Instant.ofEpochMilli(digestAt).atZone(ZoneId.systemDefault()).toLocalDate().toString()
                    val debug=context.getSharedPreferences("daymind_debug",Context.MODE_PRIVATE)
                    val digestKey=MessageDigest.getInstance("SHA-256").digest("__digest__:local|$digestDate".toByteArray()).joinToString(""){"%02x".format(it)}
                    val key=if(fixture=="digest") { if(command=="seed"){debug.edit().putString("digestKey",digestKey).commit();digestKey}else debug.getString("digestKey",digestKey)!! } else "device-smoke-$fixture"
                    if(command=="seed") {
                        val delay=if(fixture=="past")-60000L else if(fixture=="digest")digestAt-now else 20000L
                        val settings=JSONObject().put("preset","normal").put("primaryDevice",true).put("quietEnabled",fixture=="quiet").put("groupingMinutes",10)
                        if(fixture=="digest") { val local=Instant.ofEpochMilli(digestAt).atZone(ZoneId.systemDefault());settings.put("digestEnabled",true).put("digestMinute",local.hour*60+local.minute) }
                        val minute=Calendar.getInstance().let { it.get(Calendar.HOUR_OF_DAY)*60+it.get(Calendar.MINUTE) }
                        settings.put("quietStart",minute).put("quietEnd",(minute+30)%1440)
                        db.beginTransaction()
                        try {
                            db.execSQL("INSERT OR REPLACE INTO extension_records(area,id,value,updated_ms) VALUES('notifications','settings',?,?)",arrayOf<Any?>(settings.toString(),now))
                            db.execSQL("INSERT OR REPLACE INTO tasks(id,title,description,priority,status,created_at,updated_at,revision) VALUES(?,?,'',1,0,?,?,1)",arrayOf<Any?>(key,"DayMind device smoke $fixture",now/1000,now/1000))
                            db.execSQL("INSERT OR REPLACE INTO reminder_events(event_key,task_id,rule_id,task_revision,scheduled_ms,expires_ms,state,read,title,priority,updated_ms) VALUES(?,?,'default',1,?,?,'scheduled',0,?,1,?)",arrayOf<Any?>(key,key,now+delay,now+900000,"DayMind device smoke $fixture",now))
                            if(fixture=="digest") {
                                db.execSQL("UPDATE reminder_events SET task_id='__digest__:local',rule_id='digest',task_revision=0 WHERE event_key=?",arrayOf<Any?>(key))
                                db.execSQL("INSERT OR REPLACE INTO extension_records(area,id,value,updated_ms) VALUES('digest_slots',?,?,?)",arrayOf<Any?>(key,JSONObject().put("date",digestDate).put("ownerId","local").toString(),now))
                            }
                            if(fixture=="edited")db.execSQL("UPDATE tasks SET revision=2 WHERE id=?",arrayOf<Any?>(key))
                            db.setTransactionSuccessful()
                        } finally { db.endTransaction() }
                        db.rawQuery("SELECT platform_id FROM reminder_events WHERE event_key=?",arrayOf(key)).use { it.moveToFirst();ReminderRuntime.arm(context,it.getInt(0),key,now+delay) }
                    } else if(command=="retime"&&fixture=="digest") {
                        db.rawQuery("SELECT value FROM extension_records WHERE area='notifications' AND id='settings'",null).use { rows -> rows.moveToFirst();val settings=JSONObject(rows.getString(0));settings.put("digestMinute",(settings.optInt("digestMinute")+1)%1440);db.execSQL("UPDATE extension_records SET value=? WHERE area='notifications' AND id='settings'",arrayOf<Any?>(settings.toString())) }
                        ReminderRuntime.recover(context,false)
                    } else if(command=="recover") {
                        ReminderRuntime.recover(context,true)
                    } else require(command in listOf("ready","status","secure"))
                    db.rawQuery("SELECT state FROM reminder_events WHERE event_key=?",arrayOf(key)).use { if(it.moveToFirst())answer.put("state",it.getString(0)) }
                    val notices=context.getSystemService(NotificationManager::class.java).activeNotifications
                    answer.put("notifications",notices.size)
                    if(fixture=="digest") {
                        answer.put("digestNotifications",notices.count { it.id==999999999 })
                        answer.put("digestActions",notices.firstOrNull { it.id==999999999 }?.notification?.actions?.size ?: 0)
                        db.rawQuery("SELECT COUNT(*) FROM delivery_logs WHERE event_key=? AND outcome='display_attempt'",arrayOf(key)).use { it.moveToFirst();answer.put("attempts",it.getInt(0)) }
                    }
                    answer.put("foreground",ReminderRuntime.foreground)
                } ?: answer.put("ready",false)
            } catch(error:Exception){answer.put("error",error.javaClass.simpleName)}
            pending.resultData=Base64.encodeToString(answer.toString().toByteArray(),Base64.NO_WRAP)
            pending.finish()
        }
    }
}
