# Pure-logic test harness

Standalone Kotlin that exercises the framework-free algorithms verbatim
(MathPuzzle and AlarmSession are copied from the app unchanged; SchedulerLogic
and PayloadLogic mirror AlarmScheduler/NfcManager line-for-line). No Android SDK
needed.

    kotlinc *.kt ../android/app/src/main/kotlin/com/example/nfcalarm/core/MathPuzzle.kt \
            ../android/app/src/main/kotlin/com/example/nfcalarm/core/AlarmSession.kt \
            -include-runtime -d test.jar
    java -jar test.jar

Covers: puzzle expression == stated answer (200k cases), tag AND-logic,
one-shot/recurring next-trigger + weekday mapping, the post-fire double-fire
guard, and payload offset/hex round-trip incl. hardware-UID-bound HMAC verify
and clone rejection. Last run: 400031 passed, 0 failed.
