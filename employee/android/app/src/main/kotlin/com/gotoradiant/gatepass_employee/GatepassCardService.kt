package com.gotoradiant.gatepass_employee

import android.app.KeyguardManager
import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.os.SystemClock

internal object NfcPassState {
    private var credential: ByteArray? = null
    private var deadline = 0L
    private var sent = false

    @Synchronized
    fun arm(value: ByteArray) {
        clear()
        credential = value
        deadline = SystemClock.elapsedRealtime() + 30_000
    }

    @Synchronized
    fun clear() {
        credential?.fill(0)
        credential = null
        deadline = 0L
        sent = false
    }

    @Synchronized
    fun status(): String {
        if (sent) return "sent"
        if (SystemClock.elapsedRealtime() < deadline) return "ready"
        clear()
        return "idle"
    }

    @Synchronized
    fun response(): ByteArray? {
        if (status() != "ready") return null
        val value = credential ?: return null
        val reply = value + byteArrayOf(0x90.toByte(), 0x00)
        clear()
        sent = true
        return reply
    }
}

class GatepassCardService : HostApduService() {
    private val selectAid = byteArrayOf(
        0x00, 0xA4.toByte(), 0x04, 0x00, 0x07, 0xF0.toByte(),
        0x47, 0x41, 0x54, 0x45, 0x50, 0x41
    )
    private val readCredential = byteArrayOf(0x80.toByte(), 0xCA.toByte(), 0x00, 0x00, 0x20)
    private var selected = false

    override fun processCommandApdu(command: ByteArray, extras: Bundle?): ByteArray {
        if (command.contentEquals(selectAid) || command.contentEquals(selectAid + 0x00.toByte())) {
            selected = true
            return byteArrayOf(0x90.toByte(), 0x00)
        }
        if (!command.contentEquals(readCredential)) return byteArrayOf(0x6D, 0x00)
        if (selected && !getSystemService(KeyguardManager::class.java).isDeviceLocked) {
            NfcPassState.response()?.let { return it }
        }
        return byteArrayOf(0x69, 0x85.toByte())
    }

    override fun onDeactivated(reason: Int) {
        selected = false
    }
}
