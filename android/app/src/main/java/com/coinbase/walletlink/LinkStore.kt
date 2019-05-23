package com.coinbase.walletlink

import java.util.concurrent.locks.ReentrantLock
import com.coinbase.walletlink.models.Session
import com.coinbase.store.interfaces.StoreInterface
import com.coinbase.walletlink.models.StoreKeys
import io.reactivex.Observable
import kotlin.concurrent.withLock

class LinkStore(private val store: StoreInterface) {
    private val accessQueue = ReentrantLock()

    // Get stored sessions
    val sessions: List<Session> get() = getStoredSessions()

    /**
     * Store session/secret to keychain
     *
     * @param sessionId Session ID generated by the host
     * @param secret Secret generated by the host
     */
    fun save(sessionId: String, secret: String) {
        accessQueue.withLock {
            val sessionIds = (store.get(StoreKeys.sessions) ?: arrayOf()).filter { it != sessionId }.toMutableList()
            sessionIds.add(sessionId)

            store.set(StoreKeys.secret(sessionId), secret)
            store.set(StoreKeys.sessions, sessionIds.toTypedArray())
        }
    }

    /**
     * Deletes sessionID from keychain
     *
     * @param sessionId Session ID generated by the host
     */
    fun delete(sessionId: String) {
        accessQueue.withLock {
            val sessionIds = (store.get(StoreKeys.sessions) ?: arrayOf()).filter { it != sessionId }.toMutableList()

            store.set(StoreKeys.secret(sessionId), null)
            store.set(StoreKeys.sessions, sessionIds.toTypedArray())
        }
    }

    // / Observe for distinct stored sessionIds update
    fun observeSessions(): Observable<Array<String>> {
        return store.observe(StoreKeys.sessions).map { it.element ?: arrayOf() }.distinctUntilChanged()
    }

    // Private helpers

    private fun getStoredSessions(): List<Session> {
        var result = listOf<Session>()

        accessQueue.withLock {
            val sessionIds = store.get(StoreKeys.sessions) ?: arrayOf()
            result = sessionIds.mapNotNull { sessionId ->
                val secretStoreKey = StoreKeys.secret(sessionId)
                val secret = store.get(secretStoreKey) ?: return@mapNotNull null

                return@mapNotNull Session(sessionId, secret)
            }
        }

        return result
    }
}
