package com.example.nfcalarm.core
import java.util.Calendar
import java.security.SecureRandom
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import java.security.MessageDigest

var pass = 0; var fail = 0
fun check(name: String, cond: Boolean) { if (cond) { pass++ } else { fail++; println("  FAIL: $name") } }

fun cal(y:Int,mo:Int,d:Int,h:Int,mi:Int): Calendar =
    Calendar.getInstance().apply { clear(); set(y,mo,d,h,mi,0) }

fun main() {
    // ---------- MathPuzzle: expression must evaluate to the stated answer ----------
    val re = Regex("""\((\d+) ([+\-]) (\d+)\) ([+\-]) \((\d+) × (\d+)\)""")
    repeat(200000) {
        val p = MathPuzzle.generate()
        val m = re.matchEntire(p.expression)
        check("puzzle parses: ${p.expression}", m != null)
        if (m != null) {
            val (a,o1,b,o2,c,d) = m.destructured
            val g1 = if (o1=="+") a.toInt()+b.toInt() else a.toInt()-b.toInt()
            val g2 = c.toInt()*d.toInt()
            val ans = if (o2=="+") g1+g2 else g1-g2
            check("puzzle answer correct for ${p.expression}", ans == p.answer)
        }
    }

    // ---------- AlarmSession: AND logic ----------
    AlarmSession.begin("a1", listOf("t1","t2","t3"))
    check("not complete at start", !AlarmSession.isComplete())
    check("tap t1 new", AlarmSession.tap("t1"))
    check("tap t1 again -> false", !AlarmSession.tap("t1"))
    check("count=1", AlarmSession.tappedCount()==1)
    check("wrong tag ignored", !AlarmSession.tap("zzz"))
    check("remaining t2,t3", AlarmSession.remaining()==listOf("t2","t3"))
    AlarmSession.tap("t2"); AlarmSession.tap("t3")
    check("complete after all", AlarmSession.isComplete())
    AlarmSession.begin("a2", emptyList())
    check("empty required never complete", !AlarmSession.isComplete())

    // ---------- Scheduler: one-shot ----------
    val now = cal(2026,7,22,10,0) // Sat 22 Aug 2026, 10:00
    val oneShot = TAlarm(7,0, List(7){false})
    val t1 = SchedulerLogic.nextTriggerMillis(oneShot, now)!!
    val c1 = Calendar.getInstance().apply { timeInMillis = t1 }
    check("one-shot 07:00 past -> tomorrow", c1.get(Calendar.DAY_OF_MONTH)==23 && c1.get(Calendar.HOUR_OF_DAY)==7)

    val oneShotFuture = TAlarm(15,30, List(7){false})
    val t2 = SchedulerLogic.nextTriggerMillis(oneShotFuture, now)!!
    val c2 = Calendar.getInstance().apply { timeInMillis = t2 }
    check("one-shot 15:30 future -> today", c2.get(Calendar.DAY_OF_MONTH)==22 && c2.get(Calendar.HOUR_OF_DAY)==15)

    // exactly now -> should push to tomorrow (<= threshold)
    val exactNow = TAlarm(10,0, List(7){false})
    val t3 = SchedulerLogic.nextTriggerMillis(exactNow, now)!!
    val c3 = Calendar.getInstance().apply { timeInMillis = t3 }
    check("one-shot == now -> tomorrow", c3.get(Calendar.DAY_OF_MONTH)==23)

    // ---------- Scheduler: recurring weekday index mapping ----------
    // repeatDays Mon..Sun. Sat=index5. now is Saturday 10:00, alarm 07:00 Sat only -> next Saturday (29th)
    val satOnly = TAlarm(7,0, List(7){ it==5 })
    val ts = SchedulerLogic.nextTriggerMillis(satOnly, now)!!
    val cs = Calendar.getInstance().apply { timeInMillis = ts }
    check("Sat-only 07:00 (past today) -> next Sat 29", cs.get(Calendar.DAY_OF_MONTH)==29 && cs.get(Calendar.DAY_OF_WEEK)==Calendar.SATURDAY)

    // Sat 15:30 future, Sat only -> today 22nd
    val satFuture = TAlarm(15,30, List(7){ it==5 })
    val tsf = Calendar.getInstance().apply { timeInMillis = SchedulerLogic.nextTriggerMillis(satFuture, now)!! }
    check("Sat-only 15:30 future -> today 22", tsf.get(Calendar.DAY_OF_MONTH)==22)

    // Weekdays Mon-Fri, now Sat -> next Monday 24
    val weekdays = TAlarm(7,0, List(7){ it<5 })
    val tw = Calendar.getInstance().apply { timeInMillis = SchedulerLogic.nextTriggerMillis(weekdays, now)!! }
    check("Weekdays from Sat -> Mon 24", tw.get(Calendar.DAY_OF_MONTH)==24 && tw.get(Calendar.DAY_OF_WEEK)==Calendar.MONDAY)

    // Sunday only, now Sat -> tomorrow Sun 23
    val sunOnly = TAlarm(9,0, List(7){ it==6 })
    val tsu = Calendar.getInstance().apply { timeInMillis = SchedulerLogic.nextTriggerMillis(sunOnly, now)!! }
    check("Sun-only from Sat -> Sun 23", tsu.get(Calendar.DAY_OF_MONTH)==23 && tsu.get(Calendar.DAY_OF_WEEK)==Calendar.SUNDAY)

    // ---------- Scheduler: double-fire guard (post-fire reschedule) ----------
    // Simulate firing at exactly 07:00 Sat for a daily alarm; reschedule with 60s lead
    // must NOT return today 07:00 again (would double-fire), must be tomorrow.
    val daily = TAlarm(7,0, List(7){true})
    val fireNow = cal(2026,7,22,7,0)
    val nextAfterFire = Calendar.getInstance().apply {
        timeInMillis = SchedulerLogic.nextTriggerMillis(daily, fireNow, 60_000L)!!
    }
    check("daily reschedule after fire -> tomorrow 23 (no same-minute)", nextAfterFire.get(Calendar.DAY_OF_MONTH)==23)

    // And a hair BEFORE the boundary (broadcast arrives 500ms early) still must skip today
    val fireEarly = Calendar.getInstance().apply { clear(); set(2026,7,22,6,59,59); set(Calendar.MILLISECOND,500) }
    val nextEarly = Calendar.getInstance().apply {
        timeInMillis = SchedulerLogic.nextTriggerMillis(daily, fireEarly, 60_000L)!!
    }
    check("daily reschedule 0.5s early + 60s lead -> tomorrow 23", nextEarly.get(Calendar.DAY_OF_MONTH)==23)
    // without the lead guard this would be TODAY 07:00 (the bug we fixed):
    val nextNoLead = Calendar.getInstance().apply {
        timeInMillis = SchedulerLogic.nextTriggerMillis(daily, fireEarly, 0L)!!
    }
    check("control: no-lead would double-fire today 22", nextNoLead.get(Calendar.DAY_OF_MONTH)==22)

    // ---------- Payload: offsets + page math + hex round trip ----------
    check("offsets sum to TOTAL_LEN",
        PayloadLogic.MAGIC.size + PayloadLogic.UUID_LEN + PayloadLogic.HMAC_LEN + 12 == PayloadLogic.TOTAL_LEN)
    check("UUID_OFFSET after magic", PayloadLogic.UUID_OFFSET == PayloadLogic.MAGIC.size)
    check("HMAC_OFFSET after uuid", PayloadLogic.HMAC_OFFSET == PayloadLogic.UUID_OFFSET + PayloadLogic.UUID_LEN)
    val wp = PayloadLogic.writePages(ByteArray(64))
    check("16 page writes", wp.size==16)
    check("first page = 4", wp.first().first==4)
    check("last page = 19", wp.last().first==19)

    // round-trip: build payload, chunk to pages, "read" in 16-byte blocks starting at 4,8,12,16, reassemble
    val uuid = ByteArray(16).also { SecureRandom().nextBytes(it) }
    val key = ByteArray(32).also { SecureRandom().nextBytes(it) }
    val hwUid = ByteArray(7).also { SecureRandom().nextBytes(it) }
    val mac = Mac.getInstance("HmacSHA256").apply { init(SecretKeySpec(key,"HmacSHA256")) }
    val hmac = mac.doFinal(hwUid + uuid)
    val payload = PayloadLogic.buildPayload(uuid, hmac)
    // emulate tag memory: each readPages(p) returns 16 bytes = pages p..p+3
    val pageData = mutableMapOf<Int, ByteArray>()
    for (p in intArrayOf(4,8,12,16)) {
        val blk = ByteArray(16)
        val startByte = (p-4)*4
        System.arraycopy(payload, startByte, blk, 0, 16)
        pageData[p] = blk
    }
    val readBack = PayloadLogic.readReassemble(pageData)
    with(PayloadLogic) {
        check("magic reads back", readBack.copyOfRange(0,4).contentEquals(MAGIC))
        val rUuid = readBack.copyOfRange(UUID_OFFSET, UUID_OFFSET+UUID_LEN)
        val rHmac = readBack.copyOfRange(HMAC_OFFSET, HMAC_OFFSET+HMAC_LEN)
        check("uuid round-trips", rUuid.contentEquals(uuid))
        check("hmac round-trips", rHmac.contentEquals(hmac))
        // verification: recompute HMAC(hwUid||uuid) constant-time compare
        val recomputed = Mac.getInstance("HmacSHA256").apply { init(SecretKeySpec(key,"HmacSHA256")) }.doFinal(hwUid + rUuid)
        check("HMAC verifies for genuine tag", MessageDigest.isEqual(recomputed, rHmac))
        // clone to different hardware UID must FAIL
        val cloneUid = ByteArray(7).also { SecureRandom().nextBytes(it) }
        val cloneRecomputed = Mac.getInstance("HmacSHA256").apply { init(SecretKeySpec(key,"HmacSHA256")) }.doFinal(cloneUid + rUuid)
        check("clone on different UID FAILS verification", !MessageDigest.isEqual(cloneRecomputed, rHmac))
        // hex round trip
        check("hex round-trips", uuid.toHex().hexToBytes().contentEquals(uuid))
        check("hex length 32", uuid.toHex().length==32)
    }

    println("\n== $pass passed, $fail failed ==")
    if (fail>0) kotlin.system.exitProcess(1)
}
