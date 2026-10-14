package dev.cdenn.nearfield.data.room

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * OPTIONAL — Room equivalent of NfcTagRecord. Not wired by default. See
 * README-phase3.md ("Optional: Room") for the Gradle setup and how to switch
 * NfcTagStore usage over to NfcTagRepository.
 */
@Entity(tableName = "nfc_tags")
data class NfcTagEntity(
    @PrimaryKey val uuid: String,
    val name: String?,
    val locationType: String?,
    val registeredAt: Long
)
