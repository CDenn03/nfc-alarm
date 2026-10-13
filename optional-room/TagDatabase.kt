package com.example.nfcalarm.data.room

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import com.example.nfcalarm.data.NfcTagRecord

/** OPTIONAL — see README-phase3.md. */
@Database(entities = [NfcTagEntity::class], version = 1, exportSchema = false)
abstract class TagDatabase : RoomDatabase() {
    abstract fun nfcTagDao(): NfcTagDao

    companion object {
        @Volatile
        private var instance: TagDatabase? = null

        fun get(context: Context): TagDatabase = instance ?: synchronized(this) {
            instance ?: Room.databaseBuilder(
                context.applicationContext, TagDatabase::class.java, "nfc_alarm.db"
            ).build().also { instance = it }
        }
    }
}

/**
 * Drop-in replacement for NfcTagStore backed by Room. Same method surface, so
 * swapping `NfcTagStore(context)` -> `NfcTagRepository(context)` in MainActivity
 * is the only call-site change.
 *
 * WARNING: DAO calls here are synchronous — keep MainActivity's calls off the
 * main thread (the NFC callback thread is already fine; getTags() from a Pigeon
 * sync method runs on the platform thread, so consider making it @async if you
 * adopt Room).
 */
class NfcTagRepository(context: Context) {
    private val dao = TagDatabase.get(context).nfcTagDao()

    fun getAll(): List<NfcTagRecord> = dao.getAll().map { it.toRecord() }
    fun get(uuid: String): NfcTagRecord? = dao.get(uuid)?.toRecord()
    fun put(record: NfcTagRecord) = dao.put(record.toEntity())
    fun rename(uuid: String, name: String?, locationType: String?) = dao.rename(uuid, name, locationType)
    fun remove(uuid: String) = dao.remove(uuid)

    private fun NfcTagEntity.toRecord() = NfcTagRecord(uuid, name, locationType, registeredAt)
    private fun NfcTagRecord.toEntity() = NfcTagEntity(uuid, name, locationType, registeredAt)
}
