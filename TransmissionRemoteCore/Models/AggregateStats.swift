import Foundation

public struct AggregateStats {
    private(set) public var server: String
    private(set) public var freeSpaceBytes: Int64
    private(set) public var freeSpaceFormatted: String
    private(set) public var totalBytesPerSecDown: Int64
    private(set) public var totalBytesPerSecUp: Int64
    private(set) public var downloadSpeedFormatted: String
    private(set) public var uploadSpeedFormatted: String
    
    init(
        serverVersion: String,
        freeSpace: Int64,
        downSpeed: Int64,
        upSpeed: Int64
    ) {
        self.server = "Transmission " + serverVersion
        self.freeSpaceBytes = freeSpace
        self.totalBytesPerSecDown = downSpeed
        self.totalBytesPerSecUp = upSpeed
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        self.freeSpaceFormatted = formatter.string(fromByteCount: freeSpace)
        self.downloadSpeedFormatted = formatter.string(fromByteCount: downSpeed) + "/s"
        self.uploadSpeedFormatted = formatter.string(fromByteCount: upSpeed) + "/s"
    }
}
