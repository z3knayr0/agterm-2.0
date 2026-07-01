import Foundation

/// Remote peer session management
@MainActor
public final class RemoteSession: Sendable {
    public struct Peer: Identifiable, Codable, Sendable {
        public let id: UUID
        public let name: String
        public let host: String
        public let port: Int
        public var isConnected: Bool = false
        public var lastSeen: Date?

        public init(name: String, host: String, port: Int) {
            self.id = UUID()
            self.name = name
            self.host = host
            self.port = port
        }
    }

    private var peers: [Peer] = []
    private var connectedPeers: Set<UUID> = []

    /// Add a peer
    public func addPeer(_ name: String, host: String, port: Int) -> UUID {
        let peer = Peer(name: name, host: host, port: port)
        peers.append(peer)
        return peer.id
    }

    /// Connect to peer
    public func connect(peerID: UUID) -> Bool {
        guard let index = peers.firstIndex(where: { $0.id == peerID }) else { return false }
        peers[index].isConnected = true
        peers[index].lastSeen = Date()
        connectedPeers.insert(peerID)
        return true
    }

    /// Disconnect from peer
    public func disconnect(peerID: UUID) {
        guard let index = peers.firstIndex(where: { $0.id == peerID }) else { return }
        peers[index].isConnected = false
        connectedPeers.remove(peerID)
    }

    /// Get all peers
    public func all() -> [Peer] {
        peers
    }

    /// Get connected peers
    public func connected() -> [Peer] {
        peers.filter { connectedPeers.contains($0.id) }
    }

    /// Sync session state to peers
    public func sync() -> [(peerID: UUID, success: Bool)] {
        connected().map { (peerID: $0.id, success: true) }
    }

    /// Remove peer
    public func removePeer(_ peerID: UUID) {
        peers.removeAll { $0.id == peerID }
        connectedPeers.remove(peerID)
    }
}
