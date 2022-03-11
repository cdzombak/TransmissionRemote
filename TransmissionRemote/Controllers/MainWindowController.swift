import Cocoa
import PromiseKit
import TransmissionRemoteCore

protocol TorrentActionsDelegate: AnyObject {
    func startTorrents(_: [Torrent])
    func startTorrentsNow(_: [Torrent])
    func stopTorrents(_: [Torrent])
    func removeTorrents(_: [Torrent], andData: Bool)
    func reannounce(_: [Torrent])
}

class MainWindowController: NSWindowController, NSWindowDelegate, NSSearchFieldDelegate, TorrentActionsDelegate {
    
    @IBOutlet weak var panelSwithcer: NSSegmentedControl!
    @IBOutlet weak var startTorrentButton: NSToolbarItem!
    @IBOutlet weak var stopTorrentButton: NSToolbarItem!
    @IBOutlet weak var removeTorrentButton: NSToolbarItem!
    @IBOutlet weak var activityIndicator: NSProgressIndicator!
    
    var verticalSplit: NSSplitViewController!
    var horizontalSplit: NSSplitViewController!
    var serverDetailsPane: NSSplitViewItem!
    var torrentDetailsPane: NSSplitViewItem!
    var torrentsListController: TorrentsListController!
    var filterTask: DispatchWorkItem?
    
    private var currentRequests = 0
    private var showingToolbarCustomizationSheet = false

    override func windowDidLoad() {
        super.windowDidLoad()
    
        self.verticalSplit = self.window?.contentViewController as? NSSplitViewController
        self.horizontalSplit = self.verticalSplit.splitViewItems[1].viewController as? NSSplitViewController
        
        self.torrentDetailsPane = self.horizontalSplit.splitViewItems[1]
        self.serverDetailsPane = self.verticalSplit.splitViewItems[0]
        self.torrentsListController = self.horizontalSplit.splitViewItems[0].viewController as? TorrentsListController
        self.torrentsListController.actionDelegate = self
        self.torrentDetailsPane.minimumThickness = 300
        self.torrentDetailsPane.canCollapse = true
        self.serverDetailsPane.minimumThickness = 200
        self.serverDetailsPane.canCollapse = true
        
        UserDefaults.standard.register(defaults: ["ShowServerDetails": true, "ShowTorrentDetails": false])
        
        self.serverDetailsPane.isCollapsed = !UserDefaults.standard.bool(forKey: "ShowServerDetails")
        self.torrentDetailsPane.isCollapsed = !UserDefaults.standard.bool(forKey: "ShowTorrentDetails")
        self.panelSwithcer.setSelected(!self.serverDetailsPane.isCollapsed, forSegment: 0)
        self.panelSwithcer.setSelected(!self.torrentDetailsPane.isCollapsed, forSegment: 1)
        
        self.startTorrentButton.isEnabled = false
        self.stopTorrentButton.isEnabled = false
        self.removeTorrentButton.isEnabled = false
        self.activityIndicator.isDisplayedWhenStopped = false
        self.activityIndicator.stopAnimation(nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateToolbarButtons(_:)), name: .selectedTorrentsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateToolbarButtonsSoon(_:)), name: .updateTorrents, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(apiRequestStarted(_:)), name: .requestStarted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(apiRequestFinished(_:)), name: .requestFinished, object: nil)
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("NSMenuItemSelectedNotification"), object: nil, queue: nil) { [weak self] note in
            if (note.userInfo?["MenuItem"] as? NSMenuItem)?.action == #selector(NSWindow.runToolbarCustomizationPalette(_:)) {
                self?.showingToolbarCustomizationSheet = true
                self?.activityIndicator.isDisplayedWhenStopped = true
            }
        }
    }
    
    func windowDidEndSheet(_ notification: Notification) {
        if showingToolbarCustomizationSheet {
            activityIndicator.isDisplayedWhenStopped = false
        }
        showingToolbarCustomizationSheet = false
    }

    override func awakeFromNib() {
        self.window?.setFrameAutosaveName("MainWnd")
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if Settings.shared.closingWindowQuitsApp {
            return true
        } else {
            NSApp.hide(nil)
            return false
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        if Settings.shared.closingWindowQuitsApp {
            NSApp.terminate(nil)
        }
    }
    
    // MARK: - Toolbar buttons actions
    
    @objc func updateToolbarButtons(_ notification: Notification) {
        let selectedTorrents = self.torrentsListController.getSelectedTorrents()
        let stoppedCount = selectedTorrents.filter { $0.getStatus() == .stopped }.count
        self.startTorrentButton.isEnabled = stoppedCount > 0
        self.stopTorrentButton.isEnabled = stoppedCount != selectedTorrents.count
        self.removeTorrentButton.isEnabled = selectedTorrents.count > 0
    }
    
    @objc func updateToolbarButtonsSoon(_ notification: Notification) {
        // this is a hack: it allows the list view's torrents to be updated by the notification first,
        // since we fetch the view's selected torrents in order to update toolbar state
        DispatchQueue.main.async() {
            self.updateToolbarButtons(notification)
        }
    }
    
    @objc func apiRequestStarted(_ notification: Notification) {
        currentRequests += 1
        if currentRequests == 1 {
            activityIndicator.startAnimation(nil)
        }
    }
    
    @objc func apiRequestFinished(_ notification: Notification) {
        currentRequests -= 1
        if currentRequests <= 0 {
            currentRequests = 0
            activityIndicator.stopAnimation(nil)
        }
    }
    
    @IBAction func showPane(_ sender: NSSegmentedControl) {
        let selected = sender.isSelected(forSegment: sender.selectedSegment)
        if sender.selectedSegment == 0 {
            self.serverDetailsPane.animator().isCollapsed = !selected
            UserDefaults.standard.set(selected, forKey: "ShowServerDetails")
        } else {
            self.torrentDetailsPane.animator().isCollapsed = !selected
            UserDefaults.standard.set(selected, forKey: "ShowTorrentDetails")
        }
        UserDefaults.standard.synchronize()
    }
    
    @IBAction func addTorrentFile(_ sender: NSMenuItem) {
        self.selectTorrentFile()
            .done(self.openTorrentFile)
            .catch {
                print("Error adding torrent: \($0)")
            }
    }
    
    @IBAction func addLink(_ sender: NSMenuItem) {
        self.openAddLinkSheet()
            .done(self.openMagnetLink)
            .catch {
                print("Error adding torrent: \($0)")
            }
    }
    
    @IBAction func removeTorrent(_ sender: NSMenuItem) {
        self.removeSelectedTorrents(withData: false)
    }
    
    @IBAction func removeTorrentAndData(_ sender: NSMenuItem) {
        self.removeSelectedTorrents(withData: true)
    }
    
    @IBAction func startTorrents(_ sender: NSToolbarItem) {
        self.startTorrents(self.torrentsListController.getSelectedTorrents())
    }
    
    @IBAction func stopTorrents(_ sender: NSToolbarItem) {
        self.stopTorrents(self.torrentsListController.getSelectedTorrents())
    }
    
    // MARK: - Utils
    
    func selectTorrentFile() -> Promise<URL> {
        return Promise { seal in
            guard let wnd = self.window else {
                seal.reject(CocoaError.error("self.window is nil"))
                return
            }
            
            let panel = NSOpenPanel()
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.canCreateDirectories = false
            panel.allowsMultipleSelection = false
            panel.allowedFileTypes = ["torrent"]
            
            panel.beginSheetModal(for: wnd) { response in
                if response == .OK {
                    if let url = panel.url {
                        seal.fulfill(url)
                    } else {
                        seal.reject(CocoaError.error("File URL not found"))
                    }
                } else {
                    seal.reject(CocoaError.cancelError())
                }
            }
        }
    }
    
    func openAddLinkSheet() -> Promise<String> {
        return Promise { seal in
            let addLinkController = AddLinkController(nibName: "AddLinkController", bundle: nil)
            addLinkController.onOk = { url in
                seal.fulfill(url)
            }
            addLinkController.onCancel = {
                seal.reject(CocoaError.cancelError())
            }
            self.window?.contentViewController?.presentAsSheet(addLinkController)
        }
    }
    
    func openAddTorrentSheet(source: Torrent.Source) {
        let addController = AddTorrentController(nibName: "AddTorrentController", bundle: nil)
        addController.source = source
        self.window?.contentViewController?.presentAsSheet(addController)
    }
    
    func removeSelectedTorrents(withData: Bool) {
        self.removeTorrents(self.torrentsListController.getSelectedTorrents(), andData: withData)
    }
    
    func openMagnetLink(_ link: String) {
        self.openAddTorrentSheet(source: .link(link))
    }
    
    func openTorrentFile(_ url: URL) {
        self.openAddTorrentSheet(source: .file(url))
    }
	
	func hideDetailsPanel() {
		self.panelSwithcer.setSelected(false, forSegment: 1)
		self.showPane(self.panelSwithcer)
	}
    
    // MARK: TorrentActionsDelegate
    
    func startTorrents(_ torrents: [Torrent]) {
        if torrents.count < 1 {
            return
        }
        
        Api.startTorrents(by: torrents.map { $0.id }).catch { error in
            print("Error starting torrents: \(error)")
        }
        Service.shared.updateTorrents()
    }
    
    func startTorrentsNow(_ torrents: [Torrent]) {
        if torrents.count < 1 {
            return
        }
        
        Api.startTorrentsNow(by: torrents.map { $0.id }).catch { error in
            print("Error starting-now torrents: \(error)")
        }
        Service.shared.updateTorrents()
    }
    
    func stopTorrents(_ torrents: [Torrent]) {
        if torrents.count < 1 {
            return
        }
        
        Api.stopTorrents(by: torrents.map { $0.id }).catch { error in
            print("Error stopping torrents: \(error)")
        }
        Service.shared.updateTorrents()
    }
    
    func removeTorrents(_ torrents: [Torrent], andData deleteData: Bool) {
        if torrents.count < 1 {
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Confirm Removal"
        alert.informativeText = "This will remove \(torrents.count) \(torrents.count > 1 ? "torrents" : "torrent")\(deleteData ? " and delete all associated data" : ", leaving associated data on disk").\n\nYou cannot undo this action."
        alert.alertStyle = deleteData ? .critical : .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        alert.buttons[0].hasDestructiveAction = true
        
        guard let wnd = self.window else {
            print("MainWindowController's self.window is nil")
            return
        }
        
        alert.beginSheetModal(for: wnd) { result in
            if (result != .alertFirstButtonReturn) {
                return
            }
            
            Api.removeTorrents(by: torrents.map { $0.id }, deleteData: deleteData).catch { error in
                print("Error removing torrents: \(error)")
            }
            Service.shared.updateTorrents()
        }
    }
    
    func reannounce(_ torrents: [Torrent]) {
        if torrents.count < 1 {
            return
        }
        
        Api.reannounce(by: torrents.map { $0.id }).catch { error in
            print("Error reannouncing torrents: \(error)")
        }
        Service.shared.updateTorrents()
    }
    
    // MARK: - Filtering torrent list
    
    func searchFieldDidEndSearching(_ sender: NSSearchField) {
        self.torrentsListController.filterTorrents(with: "")
    }
    
    func controlTextDidChange(_ obj: Notification) {
        guard let editor = obj.userInfo?["NSFieldEditor"] as? NSTextView else { return }
        guard editor.string.count > 0 else { return }
        
        self.filterTask?.cancel()
        self.filterTask = DispatchWorkItem {
            self.torrentsListController.filterTorrents(with: editor.string)
        }
        
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.5, execute: self.filterTask!)
    }
}
