package dev.daymind.daymind_smart

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.security.MessageDigest
import java.util.Calendar
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID
import java.util.concurrent.Executors

object ReminderRuntime {
    const val CHANNEL = "daymind_tasks"
    val executor = Executors.newSingleThreadExecutor()
    private fun manager(context: Context) = context.getSystemService(NotificationManager::class.java)
    fun channel(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        manager(context).createNotificationChannel(NotificationChannel(CHANNEL, "Nhắc công việc", NotificationManager.IMPORTANCE_DEFAULT).apply {
            description = "Nhắc đúng lúc, không làm phiền"; setBypassDnd(false)
        })
    }
    fun granted(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        return manager(context).areNotificationsEnabled() && (Build.VERSION.SDK_INT < 26 || manager(context).getNotificationChannel(CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE)
    }
    fun database(context: Context): SQLiteDatabase? {
        val path = context.getSharedPreferences("daymind_runtime", Context.MODE_PRIVATE).getString("database", null) ?: return null
        return openDatabase(path)
    }
    private fun openDatabase(path: String): SQLiteDatabase? {
        if (!java.io.File(path).exists()) return null
        return SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READWRITE).apply {
            // This PRAGMA returns a row; Android's execSQL rejects row-producing statements.
            rawQuery("PRAGMA busy_timeout=5000", null).use { it.moveToFirst() }
        }
    }
    /** Call on the native executor before changing profile paths, including cold startup. */
    fun deactivate(context: Context) {
        val preferences = context.getSharedPreferences("daymind_runtime", Context.MODE_PRIVATE)
        val previous = preferences.getString("database", null)
        // Stop reads and clear visible content before touching a potentially busy old database.
        check(preferences.edit().remove("database").commit())
        manager(context).cancelAll()
        (previous?.let { openDatabase(it) })?.use { db ->
            db.rawQuery("SELECT platform_id FROM reminder_events WHERE state='scheduled' LIMIT 256", null).use { rows ->
                while(rows.moveToNext()) cancel(context, rows.getInt(0))
            }
        }
    }
    fun switchDatabase(context: Context, path: String) {
        val preferences = context.getSharedPreferences("daymind_runtime", Context.MODE_PRIVATE)
        val previous = preferences.getString("database", null)
        if(previous != null && previous != path) deactivate(context)
        check(preferences.edit().putString("database", path).commit())
    }
    private fun config(db: SQLiteDatabase): JSONObject = db.rawQuery("SELECT value FROM extension_records WHERE area='notifications' AND id='settings'", null).use {
        if (it.moveToFirst()) JSONObject(it.getString(0)) else JSONObject()
    }
    private fun quiet(config: JSONObject, instant: Long): Boolean {
        if (!config.optBoolean("quietEnabled", true)) return false
        val time = Calendar.getInstance().apply { timeInMillis = instant }; val minute = time.get(Calendar.HOUR_OF_DAY) * 60 + time.get(Calendar.MINUTE)
        val start = config.optInt("quietStart", 1320); val end = config.optInt("quietEnd", 420)
        return if (start > end) minute >= start || minute < end else minute >= start && minute < end
    }
    fun arm(context: Context, id: Int, key: String, at: Long) {
        if (at <= System.currentTimeMillis()) return
        val intent = Intent(context, ReminderAlarmReceiver::class.java).setAction("DAYMIND_ALARM").putExtra("id", id).putExtra("key", key)
        val pending = PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        context.getSystemService(AlarmManager::class.java).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
    }
    fun cancel(context: Context, id: Int) {
        val intent = Intent(context, ReminderAlarmReceiver::class.java).setAction("DAYMIND_ALARM")
        val pending = PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)
        if (pending != null) { context.getSystemService(AlarmManager::class.java).cancel(pending); pending.cancel() }
        for (visible in manager(context).activeNotifications) {
            if (visible.notification.extras.getIntArray("daymind_event_ids")?.contains(id) == true) manager(context).cancel(visible.id)
        }
    }
    private fun log(db: SQLiteDatabase, key: String, outcome: String, now: Long) {
        db.execSQL("INSERT INTO delivery_logs(id,event_key,outcome,at_ms) VALUES(?,?,?,?)", arrayOf<Any?>(UUID.randomUUID().toString(),key,outcome,now))
    }
    private fun state(db: SQLiteDatabase, key: String, state: String, outcome: String, now: Long) {
        db.execSQL("UPDATE reminder_events SET state=?,updated_ms=? WHERE event_key=?", arrayOf<Any?>(state,now,key)); log(db,key,outcome,now)
    }
    private fun owner(db: SQLiteDatabase): String = db.rawQuery("SELECT value FROM extension_records WHERE area='account' AND id='session'", null).use {
        if (it.moveToFirst()) JSONObject(it.getString(0)).optString("ownerId", "") else ""
    }
    private fun eligible(db: SQLiteDatabase, event: Cursor): Boolean {
        val taskId = event.getString(event.getColumnIndexOrThrow("task_id"))
        if (event.getString(event.getColumnIndexOrThrow("rule_id")) == "digest") {
            val activeOwner=owner(db).ifEmpty { "local" }
            return config(db).optBoolean("digestEnabled",false) && taskId=="__digest__:$activeOwner" && db.rawQuery("SELECT value FROM extension_records WHERE area='digest_slots' AND id=?",arrayOf(event.getString(event.getColumnIndexOrThrow("event_key")))).use { row -> row.moveToFirst() && JSONObject(row.getString(0)).let { meta -> meta.optString("ownerId")==activeOwner && configuredDigestAt(config(db),meta.optString("date"))==event.getLong(event.getColumnIndexOrThrow("scheduled_ms")) } }
        }
        val occurrenceId = event.getString(event.getColumnIndexOrThrow("occurrence_id"))
        val occurrenceData = if (occurrenceId == null) null else db.rawQuery("SELECT value FROM extension_records WHERE area='occurrences' AND id=?",arrayOf(occurrenceId)).use { if(it.moveToFirst())JSONObject(it.getString(0)) else null }
        val candidates = listOfNotNull(occurrenceId, occurrenceData?.optString("ruleId")?.takeIf { it.isNotEmpty() }, taskId)
        var configId = taskId
        var mode = "auto"
        for (id in candidates) {
            val stored = db.rawQuery("SELECT value FROM extension_records WHERE area='task_reminders' AND id=?",arrayOf(id)).use { if(it.moveToFirst())JSONObject(it.getString(0)) else null }
            if(stored != null) { configId = id; mode = stored.optString("mode","auto"); break }
        }
        val ruleId=event.getString(event.getColumnIndexOrThrow("rule_id"))
        if(mode=="off")return false
        if(!ruleId.startsWith("snooze:")) {
            if(ruleId=="default" && (mode!="auto" || config(db).optString("preset","normal")=="minimal"))return false
            if(ruleId!="default" && (mode!="custom" || !db.rawQuery("SELECT value FROM extension_records WHERE area='reminder_rules' AND id=?",arrayOf(ruleId)).use { if(!it.moveToFirst())false else JSONObject(it.getString(0)).let { rule -> rule.optBoolean("enabled",true) && rule.optString("taskId")==configId && (occurrenceId==null || rule.optString("kind")!="absolute" || configId==occurrenceId) } }))return false
        }
        return db.rawQuery("SELECT * FROM tasks WHERE id=? AND deleted_at IS NULL AND status NOT IN (2,3)", arrayOf(taskId)).use { task ->
            if (!task.moveToFirst() || task.getInt(task.getColumnIndexOrThrow("revision")) != event.getInt(event.getColumnIndexOrThrow("task_revision"))) return@use false
            val ownerIndex = task.getColumnIndex("owner_id")
            if (ownerIndex >= 0 && (task.getString(ownerIndex) ?: "") != owner(db)) return@use false
            val index = event.getColumnIndex("occurrence_id")
            if (index >= 0 && !event.isNull(index)) {
                val occurrence = event.getString(index)
                val valid = db.rawQuery("SELECT value FROM extension_records WHERE area='occurrences' AND id=?", arrayOf(occurrence)).use { item ->
                    if (!item.moveToFirst()) false else {
                        val data = JSONObject(item.getString(0))
                        val revision = event.getColumnIndex("occurrence_revision")
                        data.optString("taskId") == taskId && !data.optBoolean("deleted", false) && data.optString("status") !in listOf("completed","cancelled","skipped") &&
                            (revision < 0 || event.isNull(revision) || data.optInt("revision", 1) == event.getInt(revision))
                    }
                }
                if (!valid) return@use false
            }
            true
        }
    }
    internal fun digestWallInstant(zone:ZoneId,day:LocalDate,minute:Int):Long? {
        val base=day.atStartOfDay().plusMinutes(minute.toLong())
        for(delta in 0..180) {
            val local=base.plusMinutes(delta.toLong());val offsets=zone.rules.getValidOffsets(local)
            if(offsets.isNotEmpty())return local.toInstant(offsets.first()).toEpochMilli()
        }
        return null
    }
    private fun localDay(instant:Long)=Instant.ofEpochMilli(instant).atZone(ZoneId.systemDefault()).toLocalDate().toString()
    private fun digestDate(db:SQLiteDatabase,key:String):String? = db.rawQuery("SELECT value FROM extension_records WHERE area='digest_slots' AND id=?",arrayOf(key)).use { if(it.moveToFirst())JSONObject(it.getString(0)).optString("date") else null }
    private fun configuredDigestAt(cfg:JSONObject,date:String):Long? = try {
        val zone=ZoneId.systemDefault();var at=digestWallInstant(zone,LocalDate.parse(date),cfg.optInt("digestMinute",420))
        if(at!=null&&quiet(cfg,at)) {
            var candidate=(at/60000+1)*60000;var found=false
            for(n in 0 until 2880) { if(!quiet(cfg,candidate)){found=true;break};candidate+=60000 }
            at=if(found&&localDay(candidate)==date)candidate else null
        }
        at
    } catch(_:Exception){null}
    /** Bounded rolling plan is extended whenever Android wakes for any alarm/recovery. */
    internal fun ensureDigestSlots(context:Context,db:SQLiteDatabase,now:Long) {
        val cfg=config(db);if(!cfg.optBoolean("digestEnabled",false))return
        val owner=owner(db).ifEmpty { "local" };val task="__digest__:$owner";val zone=ZoneId.systemDefault();val today=Instant.ofEpochMilli(now).atZone(zone).toLocalDate()
        val minute=cfg.optInt("digestMinute",420);if(minute !in 0..1439)return
        val permitted=granted(context)&&cfg.optBoolean("primaryDevice",true)
        for(offset in 0..2) {
            val date=today.plusDays(offset.toLong());var at=digestWallInstant(zone,date,minute) ?: continue
            var end:Long?=null
            for(n in 1..3) { if(end==null)end=digestWallInstant(zone,date.plusDays(n.toLong()),0) }
            val expires=end ?: continue;var suppressed=false
            if(quiet(cfg,at)) {
                var allowed=(at/60000+1)*60000
                var found=false
                for(n in 0 until 2880) { if(!quiet(cfg,allowed)){found=true;break};allowed+=60000 }
                if(found&&localDay(allowed)==date.toString())at=allowed else suppressed=true
            }
            val key=MessageDigest.getInstance("SHA-256").digest("$task|$date".toByteArray()).joinToString(""){"%02x".format(it)}
            var id:Int?=null;var oldState:String?=null;var oldAt=0L;var oldExpires=0L
            db.rawQuery("SELECT platform_id,state,scheduled_ms,expires_ms FROM reminder_events WHERE event_key=?",arrayOf(key)).use { row -> if(row.moveToFirst()){id=row.getInt(0);oldState=row.getString(1);oldAt=row.getLong(2);oldExpires=row.getLong(3)} }
            if(oldState!=null&&oldState !in listOf("planned","scheduled","suppressed","cancelled"))continue
            if(at<=now) {
                if(oldState=="scheduled"&&oldAt<=now&&oldExpires>now&&permitted)continue
                if(id!=null&&oldState in listOf("planned","scheduled","suppressed")){cancel(context,id);state(db,key,"expired","digest_past_not_replayed",now)}
                continue
            }
            var next=if(suppressed)"suppressed" else "planned"
            if(oldState=="scheduled") {
                if(oldAt==at&&oldExpires==expires&&permitted&&!suppressed)next="scheduled" else cancel(context,id!!)
            }
            val meta=JSONObject().put("date",date.toString()).put("ownerId",owner)
            db.execSQL("INSERT OR REPLACE INTO extension_records(area,id,value,updated_ms) VALUES('digest_slots',?,?,?)",arrayOf<Any?>(key,meta.toString(),now))
            if(id==null)db.execSQL("INSERT INTO reminder_events(event_key,task_id,rule_id,task_revision,scheduled_ms,expires_ms,state,read,title,priority,updated_ms) VALUES(?,?,'digest',0,?,?,?,0,?,0,?)",arrayOf<Any?>(key,task,at,expires,next,"Bản tóm tắt ngày $date",now))
            else db.execSQL("UPDATE reminder_events SET scheduled_ms=?,expires_ms=?,state=?,updated_ms=? WHERE event_key=?",arrayOf<Any?>(at,expires,next,now,key))
        }
    }
    private fun digestTitle(db:SQLiteDatabase,now:Long):String {
        val today=localDay(now);var open=0;var overdue=0
        val parents=mutableSetOf<String>();val activeRoots=mutableSetOf<String>()
        db.rawQuery("SELECT value FROM extension_records WHERE area='recurrence'",null).use { rows -> while(rows.moveToNext()) { try { parents.add(JSONObject(rows.getString(0)).getString("taskId")) } catch(_:Exception){} } }
        fun count(due:Long?,start:Long?,end:Long?) { val late=due!=null&&due<now;if(late)overdue++;if(late||listOfNotNull(due,start,if(start==null)end else null).any { localDay(it)==today })open++ }
        db.rawQuery("SELECT * FROM tasks WHERE deleted_at IS NULL AND status NOT IN (2,3)",null).use { rows ->
            fun instant(name:String):Long? { val i=rows.getColumnIndex(name);return if(i<0||rows.isNull(i))null else rows.getLong(i)*1000 }
            while(rows.moveToNext()) { val id=rows.getString(rows.getColumnIndexOrThrow("id"));activeRoots.add(id);if(id !in parents)count(instant("due_at"),instant("scheduled_start_at"),instant("scheduled_end_at")) }
        }
        db.rawQuery("SELECT value FROM extension_records WHERE area='occurrences'",null).use { rows -> while(rows.moveToNext()) {
            try {
                val o=JSONObject(rows.getString(0));val draft=o.getJSONObject("draft");val status=o.optString("status",draft.optString("status","todo"))
                if(o.optString("taskId") !in activeRoots||o.optBoolean("deleted")||o.optBoolean("retired")||o.optBoolean("skipped")||status in listOf("completed","cancelled","skipped"))continue
                fun instant(name:String):Long? = if(draft.isNull(name))null else Instant.parse(draft.getString(name)).toEpochMilli()
                count(instant("dueAt"),instant("scheduledStartAt"),instant("scheduledEndAt"))
            } catch(_:Exception){}
        } }
        return "Hôm nay: $open việc cần làm · $overdue quá hạn"
    }
    fun recover(context: Context, restart: Boolean = true, finished: (() -> Unit)? = null) {
        executor.execute {
            try { database(context)?.use { db ->
                val now = System.currentTimeMillis(); var count = 0
                db.beginTransaction()
                try {
                ensureDigestSlots(context,db,now)
                db.rawQuery("SELECT * FROM reminder_events WHERE state IN ('planned','scheduled') ORDER BY scheduled_ms", null).use { rows ->
                    while (rows.moveToNext()) {
                        val key = rows.getString(rows.getColumnIndexOrThrow("event_key")); val id = rows.getInt(rows.getColumnIndexOrThrow("platform_id")); val at = rows.getLong(rows.getColumnIndexOrThrow("scheduled_ms"))
                        if ((restart && at <= now) || rows.getLong(rows.getColumnIndexOrThrow("expires_ms")) < now || !eligible(db,rows)) {
                            cancel(context,id);state(db,key,"expired","recovery_skipped",now)
                        } else if (at > now && granted(context) && config(db).optBoolean("primaryDevice",true) && count < 128) {
                            arm(context,id,key,at);db.execSQL("UPDATE reminder_events SET state='scheduled' WHERE event_key=?",arrayOf<Any?>(key));count++
                        } else if(at > now) { cancel(context,id);db.execSQL("UPDATE reminder_events SET state='planned' WHERE event_key=?",arrayOf<Any?>(key)) }
                    }
                }
                db.setTransactionSuccessful()
                } finally { db.endTransaction() }
            } } catch (_: Exception) { /* An older schema or locked DB is never a reason to replay alerts. */ } finally { finished?.invoke() }
        }
    }
    fun fire(context: Context, key: String) {
        database(context)?.use { db ->
            val now = System.currentTimeMillis(); var title = ""; var config = JSONObject(); var allowed = false; var isDigest = false
            db.beginTransaction()
            try {
                db.rawQuery("SELECT * FROM reminder_events WHERE event_key=? AND state='scheduled'",arrayOf(key)).use { event ->
                    if (event.moveToFirst()) {
                        isDigest = event.getString(event.getColumnIndexOrThrow("rule_id")) == "digest"
                        config = ReminderRuntime.config(db)
                        val expires = event.getLong(event.getColumnIndexOrThrow("expires_ms"))
                        when {
                            event.getLong(event.getColumnIndexOrThrow("scheduled_ms")) > now -> arm(context,event.getInt(event.getColumnIndexOrThrow("platform_id")),key,event.getLong(event.getColumnIndexOrThrow("scheduled_ms")))
                            !eligible(db,event) || (event.getString(event.getColumnIndexOrThrow("rule_id"))=="digest" && digestDate(db,key)!=localDay(now)) -> state(db,key,"cancelled","invalidated",now)
                            expires < now -> state(db,key,"expired","late_skipped",now)
                            !granted(context) || !config.optBoolean("primaryDevice",true) || quiet(config,now) -> state(db,key,"suppressed","quiet_or_permission",now)
                            else -> { title = if(event.getString(event.getColumnIndexOrThrow("rule_id"))=="digest")digestTitle(db,now) else event.getString(event.getColumnIndexOrThrow("title")); db.execSQL("UPDATE reminder_events SET title=? WHERE event_key=?",arrayOf<Any?>(title,key)); state(db,key,"unknown",if(MainActivity.foreground)"in_app" else "display_attempt",now);allowed=true }
                        }
                    }
                }
                db.setTransactionSuccessful()
            } finally { db.endTransaction() }
            if (allowed && !MainActivity.foreground) {
                val minutes = config.optInt("groupingMinutes",10).coerceIn(1,60); val window = minutes * 60000L; val start = now / window * window
                val digest=db.rawQuery("SELECT rule_id FROM reminder_events WHERE event_key=?",arrayOf(key)).use { it.moveToFirst()&&it.getString(0)=="digest" }
                val groupId = if(digest)999999999 else 1000000000 + (start / window % 1000000000L).toInt()
                val kind=if(digest)"e.rule_id='digest'" else "e.rule_id!='digest'"
                val style = NotificationCompat.InboxStyle(); var count = 0; var high = false; val visibleIds=mutableListOf<Int>()
                db.rawQuery("SELECT DISTINCT e.* FROM reminder_events e JOIN delivery_logs l ON l.event_key=e.event_key WHERE l.outcome='display_attempt' AND l.at_ms>=? AND l.at_ms<? AND e.state='unknown' AND $kind ORDER BY e.priority DESC,e.scheduled_ms",arrayOf(start.toString(),(start+window).toString())).use { rows ->
                    while(rows.moveToNext()) { if(!eligible(db,rows))continue; visibleIds.add(rows.getInt(rows.getColumnIndexOrThrow("platform_id")));if(count<7)style.addLine(rows.getString(rows.getColumnIndexOrThrow("title")));high=high || rows.getInt(rows.getColumnIndexOrThrow("priority"))==2;count++ }
                }
                if (count == 0) return
                val launch = PendingIntent.getActivity(context,groupId,Intent(context,MainActivity::class.java).putExtra("daymindOpenNotifications",true).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                val dismiss = PendingIntent.getBroadcast(context,groupId,Intent(context,ReminderActionReceiver::class.java).setAction("DAYMIND_DISMISS").putExtra("key",key).putExtra("group",groupId).putExtra("start",start).putExtra("end",start+window).putExtra("digest",digest),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                val attempts=db.rawQuery("SELECT COUNT(*) FROM delivery_logs WHERE outcome='display_attempt' AND at_ms>=? AND at_ms<?",arrayOf(start.toString(),(start+window).toString())).use { it.moveToFirst();it.getInt(0) }
                val headline = if(digest)"Nhịp ngày mới" else if(count<=1) title else "${if(high) "Ưu tiên cao · " else ""}$count công việc cần nhắc"
                val builder=NotificationCompat.Builder(context,CHANNEL).setSmallIcon(R.drawable.ic_stat_daymind).setContentTitle(headline)
                    .setContentText(if(digest)title else if(count<=1)"Mở DayMind để xem hoặc hoãn công việc." else "Mở DayMind để xem đầy đủ.")
                    .setStyle(style.setSummaryText("DayMind SMART")).setContentIntent(launch).setDeleteIntent(dismiss)
                    .setAutoCancel(true).setOnlyAlertOnce(true).setSilent(attempts>1).setPriority(NotificationCompat.PRIORITY_DEFAULT)
                    .addExtras(android.os.Bundle().apply { putIntArray("daymind_event_ids",visibleIds.toIntArray()) })
                if(count<=1 && !digest) {
                    for((action,label) in listOf("done" to "Hoàn thành","snooze" to "Hoãn 10 phút")) {
                        val intent=Intent(context,ReminderActionReceiver::class.java).setAction("DAYMIND_$action").putExtra("key",key).putExtra("group",groupId)
                        val pending=PendingIntent.getBroadcast(context,groupId, intent,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                        builder.addAction(0,label,pending)
                    }
                }
                manager(context).notify(groupId,builder.build())
            }
            MainActivity.changed(if(allowed && MainActivity.foreground) title else null, if(isDigest) "digest" else "reminder")
        }
    }
    fun action(context: Context, intent: Intent) {
        val key=intent.getStringExtra("key") ?: return;val now=System.currentTimeMillis();val action=intent.action ?: return
        database(context)?.use { db ->
            db.beginTransaction()
            try {
                if(action=="DAYMIND_DISMISS") {
                    val start=intent.getLongExtra("start",now);val end=intent.getLongExtra("end",now)
                    val kind=if(intent.getBooleanExtra("digest",false))"rule_id='digest'" else "rule_id!='digest'"
                    db.execSQL("UPDATE reminder_events SET state='dismissed',read=1,updated_ms=? WHERE state='unknown' AND $kind AND event_key IN (SELECT event_key FROM delivery_logs WHERE outcome='display_attempt' AND at_ms>=? AND at_ms<?)",arrayOf<Any?>(now,start,end))
                    log(db,key,"dismissed",now)
                } else db.rawQuery("SELECT * FROM reminder_events WHERE event_key=? AND state='unknown'",arrayOf(key)).use { event ->
                    if(event.moveToFirst() && eligible(db,event) && event.getString(event.getColumnIndexOrThrow("rule_id"))!="digest") {
                        val task=event.getString(event.getColumnIndexOrThrow("task_id"));val occurrence=event.getString(event.getColumnIndexOrThrow("occurrence_id"))
                        if(action=="DAYMIND_done") {
                            if(occurrence==null) db.execSQL("UPDATE tasks SET status=2,completed_at=?,updated_at=?,revision=revision+1 WHERE id=?",arrayOf<Any?>(now/1000,now/1000,task))
                            else db.rawQuery("SELECT value FROM extension_records WHERE area='occurrences' AND id=?",arrayOf(occurrence)).use { row ->
                                if(row.moveToFirst()) { val data=JSONObject(row.getString(0));data.put("status","completed");data.put("updatedAt",java.time.Instant.ofEpochMilli(now).toString());data.put("completedAt",java.time.Instant.ofEpochMilli(now).toString());data.put("revision",data.optInt("revision",1)+1)
                                    db.execSQL("UPDATE extension_records SET value=?,updated_ms=? WHERE area='occurrences' AND id=?",arrayOf<Any?>(data.toString(),now,occurrence)) }
                            }
                            val scope=if(occurrence==null)"task_id=?" else "task_id=? AND occurrence_id=?"
                            val args=if(occurrence==null)arrayOf(task) else arrayOf(task,occurrence)
                            db.rawQuery("SELECT platform_id FROM reminder_events WHERE $scope AND state IN ('scheduled','planned')",args).use { rows -> while(rows.moveToNext())cancel(context,rows.getInt(0)) }
                            db.execSQL("UPDATE reminder_events SET state='cancelled',updated_ms=? WHERE $scope AND state IN ('scheduled','planned')",arrayOf<Any>(now,*args));state(db,key,"dismissed","acknowledged",now)
                        } else if(action=="DAYMIND_snooze") {
                            state(db,key,"snoozed","snoozed",now);val at=now+600000
                            val next=MessageDigest.getInstance("SHA-256").digest("$key|$at".toByteArray()).joinToString(""){"%02x".format(it)}
                            db.execSQL("INSERT INTO reminder_events(event_key,task_id,rule_id,occurrence_id,occurrence_revision,task_revision,scheduled_ms,expires_ms,state,read,title,priority,updated_ms) VALUES(?,?,?,?,?,?,?,?,?,0,?,?,?)",
                                arrayOf<Any?>(next,task,"snooze:$key",occurrence,event.getInt(event.getColumnIndexOrThrow("occurrence_revision")),event.getInt(event.getColumnIndexOrThrow("task_revision")),at,at+900000,"planned",event.getString(event.getColumnIndexOrThrow("title")),event.getInt(event.getColumnIndexOrThrow("priority")),now))
                        }
                        val data=JSONObject().put("taskId",task).put("occurrenceId",occurrence).put("action",action).put("at",now)
                        db.execSQL("INSERT INTO extension_records(area,id,value,updated_ms) VALUES('native_actions',?,?,?)",arrayOf<Any?>(UUID.randomUUID().toString(),data.toString(),now))
                    }
                }
                db.setTransactionSuccessful()
            } finally { db.endTransaction() }
        }
        manager(context).cancel(intent.getIntExtra("group",0));MainActivity.changed()
    }
    fun test(context: Context,title: String,body: String) {
        channel(context);if(!granted(context))return
        manager(context).notify(2147483646,NotificationCompat.Builder(context,CHANNEL).setSmallIcon(R.drawable.ic_stat_daymind).setContentTitle(title).setContentText(body).setSilent(true).setAutoCancel(true).build())
    }
}
class ReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context,intent: Intent) {
        val key=intent.getStringExtra("key") ?: return;val pending=goAsync()
        ReminderRuntime.executor.execute { try { ReminderRuntime.fire(context,key) } catch (_:Exception) {} finally { ReminderRuntime.recover(context,false) { pending.finish() } } }
    }
}
class ReminderActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context,intent: Intent) { val pending=goAsync();ReminderRuntime.executor.execute { try { ReminderRuntime.action(context,intent) } catch (_:Exception) {} finally { ReminderRuntime.recover(context,false) { pending.finish() } } } }
}
class ReminderRecoveryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context,intent: Intent) {
        if(intent.action in listOf(Intent.ACTION_BOOT_COMPLETED,Intent.ACTION_MY_PACKAGE_REPLACED,Intent.ACTION_TIMEZONE_CHANGED,Intent.ACTION_TIME_CHANGED)) { val pending=goAsync();ReminderRuntime.recover(context) { pending.finish() } }
    }
}
