// Copyright (c) 2018-2019 Coinbase, Inc. <https://coinbase.com/>
// Licensed under the Apache License, version 2.0

import CBCore
import CBStore
import RxSwift

/// Persist session secrets
final class SessionDAO {
    private let accessQueue = DispatchQueue(label: "WalletLink.SessionStore.accessQueue")
    private let store: StoreProtocol

    required init(store: StoreProtocol = Store()) {
        self.store = store
    }

    /// Get stored sessions
    var sessions: [Session] {
        return getStoredSessions()
    }

    /// Get stored sessions filtered by url
    ///
    /// - Parameters:
    ///     - url: URL to filter sessions
    ///
    /// - Returns: Sessions for given URL
    func getSessions(for url: URL) -> [Session] {
        return getStoredSessions().filter { $0.url == url }
    }

    /// Get stored session for given sessionID and rpc URL
    ///
    /// - Parameters:
    ///     - id: Session ID
    ///     - url: URL to filter sessions
    ///
    /// - Returns: Sessions for given URL
    func getSession(id: String, url: URL) -> Session? {
        return getStoredSessions().first { $0.url == url && $0.id == id }
    }

    /// Store session/secret to keychain
    ///
    /// - Parameters:
    ///     - url: WalletLink base URL
    ///     - sessionId: Session ID generated by the host
    ///     - secret: Secret generated by the host
    ///     - version: WalletLink server version
    ///     - dappName: DApp name that initiated the new wallet link connection
    ///     - dappImageURL: DApp image that initiated the new wallet link connection
    ///     - dappURL: DApp URL that initiated the wallet link connection
    func save(
        url: URL,
        sessionId: String,
        secret: String,
        version: String?,
        dappName: String?,
        dappImageURL: URL?,
        dappURL: URL?
    ) {
        accessQueue.sync {
            var sessions = self.store.get(.sessions)?.items.filter { $0.id != sessionId && $0.url == url } ?? []

            let session = Session(
                id: sessionId,
                secret: secret,
                url: url,
                version: version,
                dappName: dappName,
                dappImageURL: dappImageURL,
                dappURL: dappURL
            )

            sessions.append(session)

            self.store.set(.sessions, value: SessionList(items: sessions))
        }
    }

    /// Deletes sessionId from keychain
    ///
    /// - Parameters:
    ///     - url: WalletLink server websocket URL
    ///     - sessionId: Session ID generated by the host
    func delete(url: URL, sessionId: String) {
        accessQueue.sync {
            let sessions = self.store.get(.sessions)?.items
                .filter { $0.id != sessionId && $0.url == url } ?? []

            self.store.set(.sessions, value: SessionList(items: sessions))
        }
    }

    /// Observe for all session updates
    ///
    /// - Returns: An observable of all sessions
    func observeSessions() -> Observable<[Session]> {
        return store.observe(.sessions)
            .map { $0?.items ?? [] }
            .distinctUntilChanged()
    }

    /// Observe for distinct stored sessionIds update
    ///
    /// - Parameters:
    ///     - url: URL to filter sessions
    ///
    /// - Returns: Session observable for given URL
    func observeSessions(for url: URL) -> Observable<[Session]> {
        return store.observe(.sessions)
            .map { list in list?.items.filter { $0.url == url }.sorted { $0.id > $1.id } ?? [] }
            .distinctUntilChanged()
    }

    // MARK: - Private helpers

    private func getStoredSessions() -> [Session] {
        return accessQueue.syncGet { (self.store.get(.sessions)?.items ?? []).sorted { $0.id > $1.id } }
    }
}
