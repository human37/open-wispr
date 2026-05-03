import AppKit

class DictionaryWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {

    private var tableView: NSTableView!
    private var entries: [DictionaryEntry] = []
    private let fromColumnID = NSUserInterfaceItemIdentifier("from")
    private let toColumnID = NSUserInterfaceItemIdentifier("to")

    static let shared = DictionaryWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 350),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Custom Dictionary"
        window.minSize = NSSize(width: 350, height: 200)
        window.center()

        super.init(window: window)

        setupUI()
        loadEntries()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reload() {
        loadEntries()
        tableView.reloadData()
    }

    private func loadEntries() {
        entries = Config.load().customDictionary ?? []
    }

    private func saveEntries() {
        var config = Config.load()
        var seen = Set<String>()
        var cleaned: [DictionaryEntry] = []
        for entry in entries.reversed() where !entry.from.isEmpty && !entry.to.isEmpty {
            if seen.insert(entry.from).inserted {
                cleaned.append(entry)
            }
        }
        cleaned.reverse()
        config.customDictionary = cleaned.isEmpty ? nil : cleaned
        try? config.save()

        if let delegate = NSApplication.shared.delegate as? AppDelegate {
            delegate.reloadConfig()
        }
    }

    private func setupUI() {
        guard let window = self.window else { return }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 36, width: contentView.bounds.width, height: contentView.bounds.height - 36))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        tableView = NSTableView()
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = true
        tableView.delegate = self
        tableView.dataSource = self

        let fromColumn = NSTableColumn(identifier: fromColumnID)
        fromColumn.title = "Whisper hears"
        fromColumn.width = 180
        fromColumn.isEditable = true
        tableView.addTableColumn(fromColumn)

        let toColumn = NSTableColumn(identifier: toColumnID)
        toColumn.title = "Should be"
        toColumn.width = 180
        toColumn.isEditable = true
        tableView.addTableColumn(toColumn)

        scrollView.documentView = tableView
        contentView.addSubview(scrollView)

        let addButton = NSButton(frame: NSRect(x: 8, y: 4, width: 24, height: 24))
        addButton.bezelStyle = .smallSquare
        addButton.title = "+"
        addButton.target = self
        addButton.action = #selector(addEntry)
        contentView.addSubview(addButton)

        let removeButton = NSButton(frame: NSRect(x: 34, y: 4, width: 24, height: 24))
        removeButton.bezelStyle = .smallSquare
        removeButton.title = "-"
        removeButton.target = self
        removeButton.action = #selector(removeEntry)
        contentView.addSubview(removeButton)

        window.contentView = contentView
    }

    @objc private func addEntry() {
        entries.append(DictionaryEntry(from: "", to: ""))
        tableView.reloadData()
        let newRow = entries.count - 1
        tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        tableView.editColumn(0, row: newRow, with: nil, select: true)
    }

    @objc private func removeEntry() {
        let selected = tableView.selectedRowIndexes
        guard !selected.isEmpty else { return }
        selected.reversed().forEach { entries.remove(at: $0) }
        tableView.reloadData()
        saveEntries()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        entries.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row < entries.count, let columnID = tableColumn?.identifier else { return nil }
        if columnID == fromColumnID { return entries[row].from }
        if columnID == toColumnID { return entries[row].to }
        return nil
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard row < entries.count, let columnID = tableColumn?.identifier, let value = object as? String else { return }
        if columnID == fromColumnID {
            entries[row].from = value.trimmingCharacters(in: .whitespaces).lowercased()
        } else if columnID == toColumnID {
            entries[row].to = value.trimmingCharacters(in: .whitespaces)
        }
        saveEntries()
    }
}
