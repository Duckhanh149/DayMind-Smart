package dev.daymind.daymind_smart

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.io.File
import java.util.Calendar
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class ReminderRuntimeTest {
    private lateinit var context: Context
    private lateinit var file: File
    private lateinit var db: SQLiteDatabase
    private val notifications get() = shadowOf(context.getSystemService(NotificationManager::class.java))
    private val now get() = System.currentTimeMillis()
    @Before fun setup() {
        context=RuntimeEnvironment.getApplication()
        file=File(context.filesDir,"${UUID.randomUUID()}.sqlite")
        db=SQLiteDatabase.openOrCreateDatabase(file,null)
        db.execSQL("CREATE TABLE tasks(id TEXT PRIMARY KEY,title TEXT,status INTEGER,revision INTEGER,deleted_at INTEGER,updated_at INTEGER,completed_at INTEGER,owner_id TEXT)")
        db.execSQL("CREATE TABLE extension_records(area TEXT,id TEXT,value TEXT,updated_ms INTEGER,PRIMARY KEY(area,id))")
        db.execSQL("CREATE TABLE reminder_events(platform_id INTEGER PRIMARY KEY AUTOINCREMENT,event_key TEXT UNIQUE,task_id TEXT,rule_id TEXT,occurrence_id TEXT,occurrence_revision INTEGER,task_revision INTEGER,scheduled_ms INTEGER,expires_ms INTEGER,state TEXT,read INTEGER,title TEXT,priority INTEGER,updated_ms INTEGER)")
        db.execSQL("CREATE TABLE delivery_logs(id TEXT PRIMARY KEY,event_key TEXT,outcome TEXT,at_ms INTEGER)")
        db.execSQL("INSERT INTO tasks VALUES('t','Việc',0,1,NULL,0,NULL,'')")
        configure(JSONObject().put("quietEnabled",false).put("primaryDevice",true).put("groupingMinutes",10))
        context.getSharedPreferences("daymind_runtime",Context.MODE_PRIVATE).edit().putString("database",file.path).commit()
        MainActivity.foreground=false;MainActivity.bridge=null
        ReminderRuntime.channel(context)
    }
    @After fun cleanup(){db.close();file.delete();MainActivity.foreground=false}
    private fun configure(settings:JSONObject){db.execSQL("INSERT OR REPLACE INTO extension_records VALUES('notifications','settings',?,?)",arrayOf<Any?>(settings.toString(),now))}
    private fun event(key:String="event",at:Long=now-1000,expires:Long=now+900000,priority:Int=1){
        db.execSQL("INSERT INTO reminder_events(event_key,task_id,rule_id,task_revision,scheduled_ms,expires_ms,state,read,title,priority,updated_ms) VALUES(?,'t','default',1,?,?,'scheduled',0,'Việc',?,?)",arrayOf<Any?>(key,at,expires,priority,now))
    }
    private fun state(key:String="event")=db.rawQuery("SELECT state FROM reminder_events WHERE event_key=?",arrayOf(key)).use{it.moveToFirst();it.getString(0)}
    private fun count(sql:String)=db.rawQuery(sql,null).use{it.moveToFirst();it.getInt(0)}
    @Test fun duplicateAlarmDoesNotRepeatDisplayAttempt(){
        event();ReminderRuntime.fire(context,"event");ReminderRuntime.fire(context,"event")
        assertEquals("unknown",state());assertEquals(1,notifications.size())
        assertEquals(1,count("SELECT COUNT(*) FROM delivery_logs WHERE outcome='display_attempt'"))
    }
    @Test fun completedOrEditedTaskInvalidatesPendingEvent(){
        event();db.execSQL("UPDATE tasks SET revision=2 WHERE id='t'")
        ReminderRuntime.fire(context,"event");assertEquals("cancelled",state());assertEquals(0,notifications.size())
        db.execSQL("UPDATE tasks SET revision=1,status=2 WHERE id='t'");event("other")
        ReminderRuntime.fire(context,"other");assertEquals("cancelled",state("other"));assertEquals(0,notifications.size())
    }
    @Test fun expiredAlarmNeverReplays(){
        event(expires=now-100);ReminderRuntime.fire(context,"event")
        assertEquals("expired",state());assertEquals(0,notifications.size())
    }
    @Test fun earlyBroadcastRearmsWithoutDisplaying(){
        event(at=now+600000);ReminderRuntime.fire(context,"event")
        assertEquals("scheduled",state());assertEquals(0,notifications.size())
        assertEquals(1,shadowOf(context.getSystemService(AlarmManager::class.java)).scheduledAlarms.size)
    }
    @Test fun cancellingAnEventRemovesItsVisibleGroup(){
        event();ReminderRuntime.fire(context,"event");assertEquals(1,notifications.size())
        val id=count("SELECT platform_id FROM reminder_events WHERE event_key='event'")
        ReminderRuntime.cancel(context,id);assertEquals(0,notifications.size())
    }
    @Test fun quietHoursAndSecondaryDeviceSuppressWithoutCompletingTask(){
        val calendar=Calendar.getInstance();val minute=calendar.get(Calendar.HOUR_OF_DAY)*60+calendar.get(Calendar.MINUTE)
        configure(JSONObject().put("quietEnabled",true).put("quietStart",minute).put("quietEnd",(minute+60)%1440))
        event();ReminderRuntime.fire(context,"event");assertEquals("suppressed",state())
        configure(JSONObject().put("quietEnabled",false).put("primaryDevice",false))
        event("secondary");ReminderRuntime.fire(context,"secondary");assertEquals("suppressed",state("secondary"))
        assertEquals(0,notifications.size());assertEquals(0,count("SELECT status FROM tasks WHERE id='t'"))
    }
    @Test fun foregroundProducesInAppActivityWithoutOSToast(){
        MainActivity.foreground=true;event();ReminderRuntime.fire(context,"event")
        assertEquals("unknown",state());assertEquals(0,notifications.size())
        assertEquals(1,count("SELECT COUNT(*) FROM delivery_logs WHERE outcome='in_app'"))
    }
    @Test fun twentyNearTimeAlarmsGroupIntoOneToastAndPreserveHighPriority(){
        for(i in 0..19){event("e$i",priority=if(i==19)2 else 1);ReminderRuntime.fire(context,"e$i")}
        assertEquals(1,notifications.size());assertEquals(20,count("SELECT COUNT(*) FROM reminder_events WHERE state='unknown'"))
        assertTrue(notifications.allNotifications.single().extras.getCharSequence("android.title").toString().contains("Ưu tiên cao"))
    }
    @Test fun dismissDoesNotCompleteAndDoubleSnoozeCreatesOneReplacement(){
        event();ReminderRuntime.fire(context,"event")
        val snooze=Intent().setAction("DAYMIND_snooze").putExtra("key","event")
        ReminderRuntime.action(context,snooze);ReminderRuntime.action(context,snooze)
        assertEquals("snoozed",state());assertEquals(2,count("SELECT COUNT(*) FROM reminder_events"))
        assertEquals(0,count("SELECT status FROM tasks WHERE id='t'"))
        event("dismiss");ReminderRuntime.fire(context,"dismiss")
        ReminderRuntime.action(context,Intent().setAction("DAYMIND_DISMISS").putExtra("key","dismiss").putExtra("start",now-60000).putExtra("end",now+60000))
        assertEquals("dismissed",state("dismiss"));assertEquals(0,count("SELECT status FROM tasks WHERE id='t'"))
    }
    @Test fun explicitDoneCompletesAndCancelsFutureTaskEvents(){
        event();event("future",at=now+600000);ReminderRuntime.fire(context,"event")
        ReminderRuntime.action(context,Intent().setAction("DAYMIND_done").putExtra("key","event"))
        assertEquals(2,count("SELECT status FROM tasks WHERE id='t'"));assertEquals("cancelled",state("future"))
    }
    @Test fun rebootRecoverySkipsPastEventsAndOnlyArmsFuture(){
        event();event("future",at=now+600000)
        val complete=CountDownLatch(1);ReminderRuntime.recover(context,true){complete.countDown()}
        assertTrue(complete.await(5,TimeUnit.SECONDS));assertEquals("expired",state());assertEquals("scheduled",state("future"))
        assertEquals(1,shadowOf(context.getSystemService(AlarmManager::class.java)).scheduledAlarms.size)
        assertEquals(0,notifications.size())
    }
    @Test @Config(sdk=[33]) fun deniedAndroid13PermissionNeverDisplays(){
        shadowOf(RuntimeEnvironment.getApplication()).denyPermissions(Manifest.permission.POST_NOTIFICATIONS)
        event();ReminderRuntime.fire(context,"event");assertFalse(ReminderRuntime.granted(context))
        assertEquals("suppressed",state());assertEquals(0,notifications.size())
    }
    private fun occurrence(id:String,taskId:String="t",status:String="todo",revision:Int=1) {
        val value=JSONObject().put("id",id).put("taskId",taskId).put("ruleId","series-rule").put("status",status).put("revision",revision)
        db.execSQL("INSERT OR REPLACE INTO extension_records VALUES('occurrences',?,?,?)",arrayOf<Any?>(id,value.toString(),now))
    }
    private fun scopedEvent(key:String,id:String,at:Long=now-1000) {
        occurrence(id);event(key,at=at)
        db.execSQL("UPDATE reminder_events SET occurrence_id=?,occurrence_revision=1 WHERE event_key=?",arrayOf<Any?>(id,key))
    }
    @Test fun completingOneOccurrenceNeverCompletesSeriesOrCancelsAnotherDate() {
        scopedEvent("first","o1");scopedEvent("next","o2",at=now+600000)
        ReminderRuntime.fire(context,"first")
        ReminderRuntime.action(context,Intent().setAction("DAYMIND_done").putExtra("key","first"))
        assertEquals(0,count("SELECT status FROM tasks WHERE id='t'"));assertEquals("scheduled",state("next"))
        val data=db.rawQuery("SELECT value FROM extension_records WHERE area='occurrences' AND id='o1'",null).use { it.moveToFirst();JSONObject(it.getString(0)) }
        assertEquals("completed",data.getString("status"));assertEquals(2,data.getInt("revision"))
    }
    @Test fun staleOrForeignOccurrenceCannotPostNotification() {
        scopedEvent("stale","o1");occurrence("o1",revision=2)
        ReminderRuntime.fire(context,"stale");assertEquals("cancelled",state("stale"))
        scopedEvent("foreign","o2");occurrence("o2",taskId="some-other-task")
        ReminderRuntime.fire(context,"foreign");assertEquals("cancelled",state("foreign"));assertEquals(0,notifications.size())
    }
    @Test fun instanceNotificationOffDoesNotDisableOtherOccurrences() {
        scopedEvent("off","o1");scopedEvent("on","o2")
        db.execSQL("INSERT INTO extension_records VALUES('task_reminders','o1',?,?)",arrayOf<Any?>(JSONObject().put("mode","off").toString(),now))
        ReminderRuntime.fire(context,"off");ReminderRuntime.fire(context,"on")
        assertEquals("cancelled",state("off"));assertEquals("unknown",state("on"));assertEquals(1,notifications.size())
    }
    @Test fun segmentCustomRuleIsAcceptedThroughOccurrenceInheritance() {
        scopedEvent("custom","o1")
        db.execSQL("INSERT INTO extension_records VALUES('task_reminders','series-rule',?,?)",arrayOf<Any?>(JSONObject().put("mode","custom").toString(),now))
        db.execSQL("INSERT INTO extension_records VALUES('reminder_rules','custom-rule',?,?)",arrayOf<Any?>(JSONObject().put("taskId","series-rule").put("enabled",true).toString(),now))
        db.execSQL("UPDATE reminder_events SET rule_id='custom-rule' WHERE event_key='custom'")
        ReminderRuntime.fire(context,"custom");assertEquals("unknown",state("custom"));assertEquals(1,notifications.size())
    }

}
