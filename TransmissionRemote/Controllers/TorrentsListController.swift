import Cocoa
import TransmissionRemoteCore
import DifferenceKit
import UserNotifications

class TorrentsListController: NSViewController, NSMenuDelegate {
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var startMenuItem: NSMenuItem!
    @IBOutlet weak var startNowMenuItem: NSMenuItem!
    @IBOutlet weak var stopMenuItem: NSMenuItem!
    @IBOutlet weak var revealInFinderItem: NSMenuItem!
    @IBOutlet weak var renameItem: NSMenuItem!
    
    weak var actionDelegate: TorrentActionsDelegate!
    
    var torrentsDS: CollectionArrayDataSource<Torrent>?

    override func viewDidLoad() {
        super.viewDidLoad()
        
		if !NSApplication.underUITest {
			self.tableView.autosaveName = "TorrentsTable"
		}
        
        self.torrentsDS = CollectionArrayDataSource<Torrent>(collectionView: self.tableView, array: [Torrent]())
        self.torrentsDS?.selectionChanged = { indices in
            let torrents = indices.map { self.torrentsDS?.item(at: IndexPath(item: $0, section: 0)) }.compactMap { $0 }
            NotificationCenter.default.post(name: .selectedTorrentsChanged, object: nil, userInfo: ["torrents": torrents])
        }
        self.torrentsDS?.setSortPredicates([
            .name: { $0.name.caseInsensitiveCompare($1.name) == .orderedAscending },
            .size: { $0.sizeWhenDone < $1.sizeWhenDone },
            .progress: { $0.downloadedPercents() < $1.downloadedPercents() },
            .seeds: { $0.peersSendingToUs < $1.peersSendingToUs },
            .peers: { $0.peersGettingFromUs < $1.peersGettingFromUs },
            .downSpeed: { $0.rateDownload < $1.rateDownload },
            .upSpeed: { $0.rateUpload < $1.rateUpload },
            .eta: { $0.eta < $1.eta },
            .ratio: { $0.uploadRatio < $1.uploadRatio },
            .priority: { $0.bandwidthPriority.rawValue < $1.bandwidthPriority.rawValue },
            .queuePosition: { $0.queuePosition < $1.queuePosition },
            .seedingTime: { $0.secondsSeeding < $1.secondsSeeding },
            .addedDate: { $0.addedDate < $1.addedDate },
            .activityDate: { $0.activityDate < $1.activityDate },
            .uploaded: { $0.uploadedEver < $1.uploadedEver },
            .downloaded: { $0.downloadedEver < $1.downloadedEver },
            .status: { $0.status < $1.status }
        ])
        
        self.setupColumns()
    }
    
    override func viewWillAppear() {
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTorrents(_:)), name: .updateTorrents, object: nil)
    }
    
    override func viewDidDisappear() {
        NotificationCenter.default.removeObserver(self, name: .updateTorrents, object: nil)
    }
    
    // MARK: - Notification handlers
    
    @objc func reloadTorrents(_ notification: Notification) {
        guard let torrents = notification.userInfo?["torrents"] as? [Torrent] else { return }
		self.torrentsDS?.setData(torrents)
    }
    
    // MARK: - NSMenuDelegate
    
    func menuWillOpen(_ menu: NSMenu) {
        let torrents = self.contextMenuTorrents()
        let stoppedCount = torrents.filter { $0.getStatus() == .stopped }.count
        let queuedCount = torrents.filter { $0.getStatus() == .downloadWait }.count
        
        self.startMenuItem.isEnabled = stoppedCount > 0
        self.startNowMenuItem.isEnabled = queuedCount > 0 || stoppedCount > 0
        self.stopMenuItem.isEnabled = stoppedCount != torrents.count
        self.revealInFinderItem.isEnabled = torrents.count == 1
        self.renameItem.isEnabled = torrents.count == 1
    }
    
    // MARK: - Utils
    
    func setupColumns() {
        guard let ad = NSApplication.shared.delegate as? AppDelegate else { return }

        let columnsView = NSMenu(title: "")
        for column in self.tableView.tableColumns {
            column.isHidden = !Settings.shared.torrentColumns.contains(column.identifier.rawValue)

            let menuItem = NSMenuItem(title: column.title, action: #selector(self.columnSelectionHandler(_:)), keyEquivalent: "")
            menuItem.state = column.isHidden ? .off : .on
            menuItem.identifier = column.identifier
            columnsView.addItem(menuItem)
        }

        ad.columnsMenu.submenu = columnsView
    }
    
    @objc func columnSelectionHandler(_ sender: NSMenuItem) {
        if let column = self.tableView.tableColumns.first(where: { $0.identifier == sender.identifier }) {
            column.isHidden = sender.state == .on
            sender.state = column.isHidden ? .off : .on
            
            if column.isHidden {
                Settings.shared.torrentColumns.removeAll { $0 == column.identifier.rawValue }
            } else {
                Settings.shared.torrentColumns.append(column.identifier.rawValue)
            }
        }
    }
    
    func filterTorrents(with text: String) {
        if text.count > 0 {
            self.torrentsDS?.setFilterPredicate { $0.name.range(of: text, options: .caseInsensitive) != nil }
        } else {
            self.torrentsDS?.removeFilterPredicate()
        }
    }
    
    func getSelectedTorrents() -> [Torrent] {
        return self.torrentsDS?.getSelectedItems() ?? []
    }
    
    func contextMenuTorrents() -> [Torrent] {
        var indexes: [Int] = []
        if self.tableView.clickedRow != -1 && !self.tableView.selectedRowIndexes.contains(self.tableView.clickedRow) {
            indexes.append(self.tableView.clickedRow)
        } else {
            indexes.append(contentsOf: self.tableView.selectedRowIndexes)
        }
        
        return indexes.map { index in
            let indexPath = IndexPath(item: index, section: 0)
            return self.torrentsDS?.item(at: indexPath) ?? nil
        }.compactMap { $0 }
    }
    
    func openClickedTorrent() {
        let indexPath = IndexPath(item: self.tableView.clickedRow, section: 0)
        guard let torrent = self.torrentsDS?.item(at: indexPath) else { return }
        guard let wnd = self.view.window else { return }
        
        torrent.withLocalPath { path, error in
            if let path = path {
                var isDir: ObjCBool = false
                if !FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
                    return
                }
                
                if isDir.boolValue {
                    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                } else {
                    NSWorkspace.shared.openFile(path)
                }
            } else if let error = error {
               error.displayAlert(for: wnd)
            } else {
               NSAlert.showError("Cannot open torrent", suggestion: "Unknown error", for: wnd)
            }
        }
    }
    
    // MARK: - Context menu actions
    
    @IBAction func startSelected(_ sender: NSMenuItem) {
        self.actionDelegate.startTorrents(self.contextMenuTorrents())
    }
    
    @IBAction func startSelectedNow(_ sender: NSMenuItem) {
        self.actionDelegate.startTorrentsNow(self.contextMenuTorrents())
    }
    
    @IBAction func stopSelected(_ sender: NSMenuItem) {
        self.actionDelegate.stopTorrents(self.contextMenuTorrents())
    }
    
    @IBAction func removeSelected(_ sender: NSMenuItem) {
        self.actionDelegate.removeTorrents(self.contextMenuTorrents(), andData: false)
    }
    
    @IBAction func removeWithDataSelected(_ sender: NSMenuItem) {
        self.actionDelegate.removeTorrents(self.contextMenuTorrents(), andData: true)
    }
    
    @IBAction func reannounceSelected(_ sender: NSMenuItem) {
        self.actionDelegate.reannounce(self.contextMenuTorrents())
    }
    
    @IBAction func revealInFinderSelected(_ sender: NSMenuItem) {
        guard let torrent = self.contextMenuTorrents().first else { return }
        guard let wnd = self.view.window else { return }
        
        torrent.withLocalPath { path, error in
            if let path = path {
                NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
            } else if let error = error {
                error.displayAlert(for: wnd)
            } else {
                NSAlert.showError("Cannot open torrent", suggestion: "Unknown error", for: wnd)
            }
        }
    }
    
    @IBAction func openSelected(_ sender: NSMenuItem) {
        self.openClickedTorrent()
    }
    
    @IBAction func doubleClick(_ sender: NSTableView) {
        self.openClickedTorrent()
    }
    
    @IBAction func setLocationSelected(_ sender: NSMenuItem) {
        let controller = SetLocationController(nibName: "SetLocationController", bundle: nil)
        controller.ids = self.contextMenuTorrents().map { $0.id }
        self.view.window?.contentViewController?.presentAsSheet(controller)
    }
    
    @IBAction func renameClicked(_ sender: NSMenuItem) {
        guard let torrent = self.getSelectedTorrents().first else { return }
        
        let controller = RenameController(nibName: "RenameController", bundle: nil)
        controller.torrent = torrent
        self.view.window?.contentViewController?.presentAsSheet(controller)
    }
    
    @IBAction func prioritySelected(_ sender: NSMenuItem) {
        let torrents = self.getSelectedTorrents().map { $0.id }
        Api.set(priority: sender.tag, for: torrents)
            .done {
                Service.shared.updateTorrents()
            }
            .catch { error in
                print("Error setting priority: ", error)
            }
    }
}
