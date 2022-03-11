import Foundation

public struct Server: Codable {
    public var version: String
    public var downloadDir: String
    public var peerLimitPerTorrent: Int
    public var incompleteDirEnabled: Bool
    public var incompleteDir: String
    public var freeSpace: Int64
    public var seedRatioLimit: Float
    public var seedRatioLimited: Bool
    
    enum CodingKeys: String, CodingKey {
        case version
        case downloadDir = "download-dir"
        case peerLimitPerTorrent = "peer-limit-per-torrent"
        case incompleteDirEnabled = "incomplete-dir-enabled"
        case incompleteDir = "incomplete-dir"
        case freeSpace = "download-dir-free-space"
        case seedRatioLimit = "seedRatioLimit"
        case seedRatioLimited = "seedRatioLimited"
    }
	
	public init() {
		version = ""
		downloadDir = ""
		peerLimitPerTorrent = 0
		incompleteDir = ""
		incompleteDirEnabled = false
		freeSpace = 0
        seedRatioLimit = 0.0
        seedRatioLimited = false
	}
}
