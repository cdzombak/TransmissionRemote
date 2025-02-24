import Cocoa
import TransmissionRemoteCore

class GeneralSettingsController: NSViewController {
    
    @IBOutlet weak var refresh: NSTextField!
    @IBOutlet weak var refreshWhenMinimized: NSTextField!
    @IBOutlet weak var deleteTorrentFile: NSButton!
    @IBOutlet weak var startAllExcludesFullySeeded: NSButton!
    @IBOutlet weak var closeBehaviorSwitch: NSPopUpButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.refresh.integerValue = Settings.shared.refreshInterval
        self.refreshWhenMinimized.integerValue = Settings.shared.refreshIntervalWhenMinimized
        self.deleteTorrentFile.state = Settings.shared.deleteTorrentFile ? .on : .off
        self.closeBehaviorSwitch.selectItem(withTag: Settings.shared.closingWindowQuitsApp ? 0 : 1)
        self.startAllExcludesFullySeeded.state = Settings.shared.startAllExcludesFullySeeded ? .on : .off
    }
    
    // MARK: - Actions
    
    @IBAction func refreshIntervalChanged(_ sender: NSTextField) {
        Settings.shared.refreshInterval = sender.integerValue
        NotificationCenter.default.post(name: .refreshIntervalChanged, object: nil, userInfo: nil)
    }
    
    @IBAction func refreshIntervalMinimizedChanged(_ sender: NSTextField) {
        Settings.shared.refreshIntervalWhenMinimized = sender.integerValue
        NotificationCenter.default.post(name: .refreshIntervalChanged, object: nil, userInfo: nil)
    }
    
    @IBAction func deleteTorrentFileChanged(_ sender: NSButton) {
        Settings.shared.deleteTorrentFile = sender.state == .on
    }
    
    @IBAction func closeBehavoirChanged(_ sender: NSButton) {
        Settings.shared.closingWindowQuitsApp = sender.selectedTag() == 0
    }
    
    @IBAction func startAllExcludesSeededTorrentsChanged(_ sender: NSButton) {
        Settings.shared.startAllExcludesFullySeeded = sender.state == .on
    }
}
