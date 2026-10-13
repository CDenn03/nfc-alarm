package com.example.nfcalarm.data.room

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

/** OPTIONAL — see README-phase3.md. */
@Dao
interface NfcTagDao {

    @Query("SELECT * FROM nfc_tags ORDER BY registeredAt DESC")
    fun getAll(): List<NfcTagEntity>

    @Query("SELECT * FROM nfc_tags WHERE uuid = :uuid LIMIT 1")
    fun get(uuid: String): NfcTagEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun put(tag: NfcTagEntity)

    @Query("UPDATE nfc_tags SET name = :name, locationType = :locationType WHERE uuid = :uuid")
    fun rename(uuid: String, name: String?, locationType: String?)

    @Query("DELETE FROM nfc_tags WHERE uuid = :uuid")
    fun remove(uuid: String)
}
