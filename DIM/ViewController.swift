//
//  ViewController.swift
//  DIM
//
//  Created by G.J. Parker on 19/1/17.
//  Copyright © 2021 G.J. Parker. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    
    // variables to deal w/ different Arrangements and what the code should do (these are default values which will be overwritten soon)
    var restoreAtStart = false  // Restore icon positions at start?
    var quitAfterStart = false  // if we are Restoring at start should we just quit afterwards?
    var automaticSave = false
    var currentName = "Default" // some name for an icon Arrangment
    var arrangements = [String: Any]()  // dictionary keyed to name w/ corresponding iconSet (AppleScript data object)
    var orderedArrangements = [String]()  // an ordered list of Arrangement names to populate drop down menu and Edit sheet
    var timerSeconds = -1
    let thisVer = 4001000
    
    // these are disposable run variables
    var start = true     // did we just start?
    var overrideSetting = false  // is user holding command (⌘) during start?
    var saveTimer: Timer?
    var dataVer = 0
    var quitTimer: Timer?
    var quitCount = 20
    
    // our outlets to various labels, buttons, etc on the main storyboard
    @IBOutlet weak var doingTF: NSTextField!
    @IBOutlet weak var doingPI: NSProgressIndicator!
    @IBOutlet weak var warningTF: NSTextField!
    @IBOutlet weak var warningButton: NSButton!
    @IBOutlet weak var quitButton: NSButton!
    @IBOutlet weak var automaticSaveButton: NSButton!
    @IBOutlet weak var timeMenu: NSPopUpButton!
    @IBOutlet weak var currentTF: NSTextField!
    @IBOutlet weak var currentNumDesktop: NSTextField!
    @IBOutlet weak var currentNumArrangement: NSTextField!
    @IBOutlet weak var arrangementButton: NSPopUpButton!
    @IBOutlet weak var restoreButton: NSButton!
    @IBOutlet weak var memorizeButton: NSButton!
    
    var dim: DIM?
    
    var hiding = false
    var hider : Hider? //= Hider(false)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        overrideSetting = NSEvent.modifierFlags == .command  // check to see if user is holding command key during launch
        NotificationCenter.default.addObserver(self, selector: #selector(self.atEnd), name: NSNotification.Name("atEnd"), object: nil)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if start {
            DispatchQueue.global(qos: .userInteractive).async {
                if self.dim == nil { self.dim = DIM() }
                DispatchQueue.main.async {
                    if self.dim == nil || self.dim!.testBridge == "no" || self.dim!.testBridge == nil {
                        self.errorwithAS()
                    } else {
                        self.loadPrefs()
                        self.start = false
                    }
                }
            }
        } /*
        if start {  // first time through?
            if dim == nil { //inject AppleScript stuff... if we haven't yet
                dim = DIM()
            }
            if dim == nil || dim!.testBridge == "no" || dim!.testBridge == nil {
                errorwithAS()   // problems talking to Finder via AppleScript
            } else {
                loadPrefs()     // load user preferences and get going
                start = false   // flag to say we did this once, no need to do it again (since viewDidAppear can be called again, say, if app was Hid or not...
            }
        }*/
    }
    
    @objc func atEnd() { // called just before quit
        if automaticSave && timerSeconds < 0 && !(restoreAtStart && quitAfterStart) {
            arrangements[currentName] = refetchSet()  // w/o gui
            savePrefs()
        }
        if saveTimer != nil { saveTimer?.invalidate(); saveTimer = nil }    // get rid of any timers
    }
    @objc func terminate() {
        quitCount -= 1
        if NSEvent.modifierFlags == .command {
            warningTF.stringValue = "(Hold ⌘ while starting DIM to reach this window)"
            quitTimer?.invalidate()
        } else if quitCount > 0 {
            warningTF.stringValue = "Hold ⌘ to abort Quit (\(Int(0.9 + Double(quitCount)/5.0)))" // triggers every 0.2 seconds
        } else {
            quitTimer?.invalidate()
            NSApp.terminate(self)
        }
    }
    @objc func atTimer() { // called if we're doing automatic saves
        if saveTimer != nil {   // make sure we are called from a timer
            arrangements[currentName] = refetchSet() // w/o gui
            savePrefs()
        }
    }
     
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    
    // Button pressed to Memorize...
    @IBAction func do_memorize(_ sender: NSButton) {
        quitTimer?.invalidate()
        memorize(currentName)
        refreshTimer()
    }
    
    // Button pressedd to Restore...
    @IBAction func do_restore(_ sender: NSButton) {
        quitTimer?.invalidate()
        restore(currentName)
        refreshTimer()
    }

    
    // memorize an arrangement given by name
    func memorize(_ name: String) {
        updateUI("Memorizing Icon Positions...")
        DispatchQueue.global(qos: .utility).async { [unowned self] in  // apparently we need to do this otherwise UI isn't updated during AppleScript call
            self.arrangements[name] = self.refetchSet()
            DispatchQueue.main.async {
                self.savePrefs()
                self.updateUI()
            }
        }
    }
    
    // restore from arrangement given by name
    func restore(_ name: String) {
        updateUI("Restoring Icon Positions...")
        DispatchQueue.global(qos: .utility).async { [unowned self] in
            self.setSet(set: self.arrangements[name]!)
            self.dim!.numOnDesktop = 0
            DispatchQueue.main.async {
                self.updateUI()
            }
        }
    }
    
    // AppleScript can take a while, turn off all controlls until it's done and do an animation so user doesn't get too confused
    func updateUI(_ message: String) {
        doingTF.stringValue = message
        memorizeButton.isEnabled = false
        restoreButton.isEnabled = false
        doingTF.isHidden = false
        doingPI.startAnimation(nil)
        warningButton.isEnabled = false
        quitButton.isEnabled = false
        warningButton.isHidden = true
        quitButton.isHidden = true
        warningTF.isHidden = true
        automaticSaveButton.isEnabled = false
        timeMenu.isEnabled = false
        automaticSaveButton.isHidden = true
        timeMenu.isHidden = true
        arrangementButton.isEnabled = false
    }
    
    // apparently AppleScript call is done, turn on the contollers again so the user can do something...
    func updateUI() {  //turn on controllers once AppleScript is done
        memorizeButton.isEnabled = true
        restoreButton.isEnabled = true
        doingTF.isHidden = true
        doingPI.stopAnimation(nil)
        warningButton.isEnabled = true
        quitButton.isEnabled = restoreAtStart
        warningButton.isHidden = false
        quitButton.isHidden = false
        warningTF.isHidden = !(restoreAtStart && quitAfterStart)
        automaticSaveButton.isHidden = (restoreAtStart && quitAfterStart)
        automaticSaveButton.isEnabled = !automaticSaveButton.isHidden
        timeMenu.isHidden = automaticSaveButton.isHidden
        timeMenu.isEnabled = !timeMenu.isHidden && automaticSaveButton.state == .on
        arrangementButton.isEnabled = true
        updateInfo()
    }
    
    //set AppleScript data and restore icon positions
    func setSet(set: Any) {
        dim!.iconSet = set
        dim!.restore()
    }
    
    // memorize icon positions and return AppleScript data
    func fetchSet() -> Any {
        dim!.memorize()
        return dim!.iconSet as Any
    }
    func refetchSet() -> Any {
        dim!.rememorize()
        return dim!.iconSet as Any
    }
    
    // Check for Restore at start was toggled
    @IBAction func restoreQuitCheck(_ sender: NSButton) { // Restore at Start?
        restoreAtStart = (sender.state.rawValue == 1)             // "1" is checked, return true in that case
        sanitize()
    }
    
    // Check for Quit after Restore was toggled
    @IBAction func quitThenCheck(_ sender: NSButton) {
        quitAfterStart = (sender.state.rawValue == 1)             // "1" is checked
        sanitize()
    }
    func sanitize() {
        quitTimer?.invalidate()
        quitButton.isEnabled = restoreAtStart                     // enable Quit after Restore if latter is checked
        warningTF.isHidden = !(restoreAtStart && quitAfterStart)  // if this is checked (we know Restore is), warn the user
        automaticSaveButton.isHidden = (restoreAtStart && quitAfterStart)
        automaticSaveButton.isEnabled = !automaticSaveButton.isHidden
        timeMenu.isHidden = automaticSaveButton.isHidden
        timeMenu.isEnabled = !timeMenu.isHidden && automaticSaveButton.state == .on
        savePrefs()
        refreshTimer()
    }
    
    func refreshTimer() {
        if saveTimer != nil { saveTimer?.invalidate(); saveTimer = nil }
        if automaticSave && timerSeconds > 0 && !(restoreAtStart && quitAfterStart) {
            saveTimer = Timer.scheduledTimer(timeInterval: TimeInterval(timerSeconds), target: self, selector: #selector(self.atTimer), userInfo: nil, repeats: true)
        }
    }
    
    @IBAction func automaticSaveCheck(_ sender: NSButton) {
        quitTimer?.invalidate()
        automaticSave = (sender.state.rawValue == 1)            // 1 if checked
        savePrefs()
        refreshTimer()
        timeMenu.isEnabled = automaticSave
    }
    
    func setTimerMenu() {
        timeMenu.removeAllItems()
        timeMenu.addItems(withTitles: ["at Quit", "every 30 minutes", "every hour", "every 2 hours", "every 6 hours", "every 12 hours", "every day"])
        var selectItem = -1
        switch timerSeconds {
        case -1:
            selectItem = 0
        case 60*30:
            selectItem = 1
        case 60*60:
            selectItem = 2
        case 60*60*2:
            selectItem = 3
        case 60*60*6:
            selectItem = 4
        case 60*60*12:
            selectItem = 5
        default:
            selectItem = 6
        }
        timeMenu.selectItem(at: selectItem)
    }
    
    @IBAction func timerInterval(_ sender: NSPopUpButton) {
        quitTimer?.invalidate()
        if let name = sender.selectedItem?.title {
            var newTimerSeconds = 0
            switch name {
            case "at Quit":
                newTimerSeconds = -1
            case "every 30 minutes":
                newTimerSeconds = 60 * 30
            case "every hour":
                newTimerSeconds = 60 * 60
            case "every 2 hours":
                newTimerSeconds = 60 * 60 * 2
            case "every 6 hours":
                newTimerSeconds = 60 * 60 * 6
            case "every 12 hours":
                newTimerSeconds = 60 * 60 * 12
            default:
                newTimerSeconds = 60 * 60 * 24
            }
            if timerSeconds != newTimerSeconds {
                timerSeconds = newTimerSeconds
                savePrefs()
                refreshTimer()
            }
        }
    }
    
    // let's read user's preferences
    func loadPrefs() {  // go read user's perferences
        if goodLoadPrefs() {  // try to be robust in reading them back in, if there is an unrecoverable problem (or data doesn't exist), start afresh
            if restoreAtStart && !overrideSetting && start {  // did they want us to restore automatically at start?
//              restore(currentName) //doesn't seem to work, so just brute force a restore  (instead of the next line)
                setSet(set: arrangements[currentName]!)
                dim!.numOnDesktop = 0  // we have to make sure numArrangement, numDesktop and iconSet is set, if we got here, we only have to update numDesktop so tell Finder to do so
                if quitAfterStart && dataVer == thisVer {  // should we quit in 5 seconds?
                    warningTF.stringValue = "Hold ⌘ to abort Quit (\(quitCount))"
                    quitTimer = Timer.scheduledTimer(timeInterval: TimeInterval(0.2), target: self, selector: #selector(self.terminate), userInfo: nil, repeats: true)
                }
            } else {
                dim!.iconSet = arrangements[currentName]!  // no automatic restore, so just load AppleScript data (iconSet, numDesktop and numSet) for current arrangment
                dim!.numInSet = 0     // tell Finder to compute
                dim!.numOnDesktop = 0 // tell Finder to compute
            }
        } else {   // first run or no user data or fatal problem reading user data
            restoreAtStart = false  // these are the defaults
            quitAfterStart = false  // let's force user to select this, perhaps it will reduce confusion
            automaticSave = false
            currentName = "Default"
            timerSeconds = -1
            orderedArrangements.append(currentName)
            arrangements[currentName] = fetchSet()  // this will cause numArrangment, numDesktop and iconSet to be defined so we are all good, it also stores the initial arrangement- we always need at least one!
            savePrefs()
            doingTF.isHidden = true
        }
        // set up timer options
        setTimerMenu()
        
        warningButton.state = (restoreAtStart ? .on : .off) // set default state of check for Restore at start
        quitButton.state = (quitAfterStart ? .on : .off)    // set default state of check for Quit after Restore at start
        quitButton.isEnabled = restoreAtStart               // if Restore at startup, allow the user to pick if we should quit or not, if not Restore at start, then don't allow the user to edit this
        warningTF.isHidden = !(restoreAtStart && quitAfterStart) // if Restore and Quit at startup, warn the user how to get back to our screen
        automaticSaveButton.isHidden = (restoreAtStart && quitAfterStart)
        automaticSaveButton.state = (automaticSave ? .on : .off)
        timeMenu.isHidden = automaticSaveButton.isHidden
        timeMenu.isEnabled = !timeMenu.isHidden && automaticSaveButton.state == .on
        loadMenu()  // finally, construct the arrangement drop down menu
        refreshTimer()
    }
    
    //let's assume something bad happened to the stored user data...
    func goodLoadPrefs() -> Bool {
        let defaults = UserDefaults.standard
        guard let name = defaults.string(forKey: "currentName")  else { return false }  // is there a plist?
        guard (defaults.array(forKey: "orderedArrangements") != nil) else { return false }
        currentName = name
        quitAfterStart = defaults.bool(forKey: "quitAfterStart")
        restoreAtStart = defaults.bool(forKey: "restoreAtStart")
        orderedArrangements = defaults.array(forKey: "orderedArrangements") as! [String]
        arrangements = defaults.dictionary(forKey: "arrangements")!
        if defaults.object(forKey: "timerSeconds") != nil {timerSeconds = defaults.integer(forKey: "timerSeconds")}
        if defaults.object(forKey: "automaticSave") != nil {automaticSave = defaults.bool(forKey: "automaticSave")}
        
        if defaults.object(forKey: "dataVer") != nil { dataVer = defaults.integer(forKey: "dataVer")}
        defaults.set(thisVer, forKey: "dataVer") // since we ran, update dataVer
        if dataVer != thisVer { defaults.removeObject(forKey: "donate") }
        if defaults.string(forKey: "donate") != nil {donateLabel.textColor = NSColor.labelColor}
        
        // in a perfect world we would be done. but let's not assume perfect and instead assume non-perfect
        // first, let's construct a new array using the data we (supposedly) have in arrangements dictionary
        var valid = [String]()  // valid will be a copy of arrangements but must be 'valid' (i.e. dictionary can be cast to NSArray with 5 or more elements)
        for (arr, data) in arrangements {
            if let dictEntry = data as? NSArray {
                if dictEntry.count > 4 {valid.append(arr)} else { arrangements[arr] = nil}
            }
        }
        var corrected = [String]() // now try to preserve the order, valid has all 'valid' arrangements
        for arr in orderedArrangements {
            if valid.contains(arr) {corrected.append(arr)} // add only if we have a dictionary key in 'valid'
        }
        if corrected.count < valid.count {  // and assume orderedArrangement was corrupt, just add what's missing
            for arr in valid {
                if !corrected.contains(arr) {corrected.append(arr)} // add only if 'corrected' doesn't have the 'valid' key
            }
        }
        if corrected.count > 0 {  // we have something, if not all
            if arrangements[currentName] == nil {  // and confirm we have a valid currentName
                currentName = corrected[0]  // oh no, we don't- grab the first one and reset flag for restoring at start
                restoreAtStart = false
            }
            orderedArrangements = corrected  // either everything was perfect or we corrected what wasn't.
            return true  // and tell them to use this data
        }
        // ah, we have unrecoverable errors
        arrangements.removeAll()
        orderedArrangements.removeAll()
        return false // we don't have sets recoverable, punt and redo
    }
    
    // save user's preferences
    func savePrefs() {
        let defaults = UserDefaults.standard
        defaults.set(currentName, forKey: "currentName")
        defaults.set(restoreAtStart, forKey: "restoreAtStart")
        defaults.set(quitAfterStart, forKey: "quitAfterStart")
        defaults.set(orderedArrangements, forKey: "orderedArrangements")
        defaults.set(arrangements, forKey: "arrangements")
        defaults.set(automaticSave, forKey: "automaticSave")
        defaults.set(timerSeconds, forKey: "timerSeconds")
    }
    
    // construct the Arrangement popdown menu
    func loadMenu() {
        updateInfo()
        if let nn = arrangementButton.menu?.numberOfItems {  // destroy the existing menus
            for num in 1 ..< nn {
                arrangementButton.menu?.removeItem(at: nn-num)
            }
            for name in orderedArrangements {               // create a new menu, first w/ all the arrangement names...
                let menuItem = NSMenuItem(title: name, action: nil, keyEquivalent: "")
                menuItem.state = (name == currentName ? .on : .off)
                arrangementButton.menu?.addItem(menuItem)
            }
            arrangementButton.menu?.addItem(NSMenuItem.separator())     // simple seperator
            let editMenu = NSMenuItem(title: "Edit...", action: #selector(editArrangement), keyEquivalent: "") // the "Edit..." option
            arrangementButton.menu?.addItem(editMenu)
            arrangementButton.menu?.addItem(NSMenuItem.separator())     // simple seperator
            let showMenu = NSMenuItem(title: "Select unmemorized Icons", action: #selector(showNewIcons), keyEquivalent: "")    // "Select unmemorized icons" option
            arrangementButton.menu?.addItem(showMenu)
            arrangementButton.menu?.addItem(NSMenuItem.separator())
            let hiderMenu = NSMenuItem(title: hiding ? "Show Desktop icons" : "Hide Desktop icons", action: #selector(doHider), keyEquivalent: "")    // "Hide/Show Desktop icons" option
            arrangementButton.menu?.addItem(hiderMenu)
            
            // for 4.0.1
            if ProcessInfo().operatingSystemVersion.minorVersion < 13 &&  ProcessInfo().operatingSystemVersion.majorVersion == 10 {
                editMenu.target = self
                editMenu.isEnabled = true
                showMenu.target = self
                showMenu.isEnabled = true
                hiderMenu.target = self
                hiderMenu.isEnabled = true
            }
            
        }
    }
    
    func updateInfo() {
        currentTF.stringValue = "Use Icon Arrangement: " + currentName  // some useful(?) info for user
        if let num = dim!.numInSet {
            if let dictEntry = arrangements[currentName] as? NSArray {
                if dictEntry.count > 5 { currentNumArrangement.stringValue = "Number of memorized window Icons: " + String(num) }
                else { currentNumArrangement.stringValue = "Number of memorized Desktop Icons: " + String(num) }
            }
        } //AppleScript data should be insync
        if let num = dim!.numOnDesktop {
            if let dictEntry = arrangements[currentName] as? NSArray {
                if dictEntry.count > 5 { currentNumDesktop.stringValue = "Number of current window Icons: " + String(num) }
                else { currentNumDesktop.stringValue = "Number of current Desktop Icons: " + String(num) }
            }
        }
    }
    
    // user selected a different(?) arrangement
    @IBAction func arrangeButton(_ sender: NSPopUpButton) {
        quitTimer?.invalidate()
        if let name = sender.selectedItem?.title {
            if name != currentName {
                currentName = name
                dim!.iconSet = arrangements[currentName]!  // sync AppleScript data
                dim!.numInSet = 0
                dim!.numOnDesktop = 0
                savePrefs()
                loadMenu()
                refreshTimer() // refresh timer if it exists
            }
        }
    }
    
    // toggle hiding/unhiding Desktop icons
    @objc func doHider(_ sender: NSMenuItem) {
        quitTimer?.invalidate()
        if hider != nil {
            NotificationCenter.default.post(name: .doHide, object: nil)
        } else {
            hider = Hider()
        }
        hiding = !hiding // toggle state
        loadMenu()
    }
    
    // user wants to highlight new icons...
    @objc func showNewIcons(_ sender: NSMenuItem) {
        quitTimer?.invalidate()
        dim!.showNewIcons()
    }
    
    // user wants to edit arrangements...
    @objc func editArrangement(_ sender: NSMenuItem) {
        quitTimer?.invalidate()
        performSegue(withIdentifier: "toEditSheet", sender: self)
    }
    
    // give EditSheet access to the global data (could use notifications, but...)
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier == "toEditSheet" {
            if let dvc = segue.destinationController as? EditSheet {
                dvc.myContainerViewDelegate = self
            }
        } else if segue.identifier == "toPlistOption" {
            if let dvc = segue.destinationController as? PlistOption {
                dvc.myContainerViewDelegate = self
            }
        }
    }
    
    @IBOutlet weak var donateLabel: NSTextField!
    // hardcoded URL for donations (oh please!)
    @IBAction func donateClicked(_ sender: NSButton) {
        quitTimer?.invalidate()
        let url = URL(string: "http://www.parker9.com/d")
        NSWorkspace.shared.open(url!)
        donateLabel.textColor = NSColor.systemGray  //labelColor.withAlphaComponent(0.2)
        UserDefaults.standard.set("done", forKey: "donate")
    }
    
    // hardcoded URL for home
    @IBAction func homeClicked(_ sender: NSButton) {
        quitTimer?.invalidate()
        let url = URL(string: "http://www.parker9.com/desktopIconManager4.html#d")
        NSWorkspace.shared.open(url!)
    }
    
    func errorwithAS() {
        if  ProcessInfo.processInfo.operatingSystemVersion.majorVersion > 12 {
            performSegue(withIdentifier: "toErrorVentura", sender: self)
        } else {
            performSegue(withIdentifier: "toError", sender: self)
        }
    }
    
// add Import and Export of UserDefaults
    @IBAction func writePlist(_ sender: NSMenuItem) {  // this will (hopefully) copy the current UserDefaults data to user specified place
        let url2 = FileManager.default.homeDirectoryForCurrentUser.path+"/Library/Preferences/com.parker9.DIM-4.plist"
        if FileManager.default.fileExists(atPath: url2) {
            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            panel.message = "Select location to export DIM Settings:"
            panel.nameFieldStringValue = "com.parker9.DIM-4.plist"
            panel.prompt = "Export"
            panel.allowedFileTypes = ["plist"]
            panel.nameFieldLabel = "Export As:"
            panel.beginSheetModal(for: self.view.window! ) {(reply) in
                if reply == .OK, let exportURL = panel.url {
                    let data = NSDictionary(dictionary: [
                        "currentName" : self.currentName,
                        "restoreAtStart" : self.restoreAtStart,
                        "quitAfterStart" : self.quitAfterStart,
                        "orderedArrangements" : self.orderedArrangements,
                        "arrangements" : self.arrangements,
                        "automaticSave" : self.automaticSave,
                        "timerSeconds" : self.timerSeconds] )
                    if !data.write(toFile: exportURL.path, atomically: true) {if #available(macOS 11.0, *) { Logger.diag.error("could create exported Settings to \(exportURL.path)")}}
                }
            }
        }
    }
    var newData : NSDictionary?
    @IBAction func readPlist(_ sender: Any) {   // import new UserDefaults
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select DIM Settings to import:"
        panel.prompt = "Import"
        panel.allowedFileTypes = ["plist"]
        panel.nameFieldLabel = "Import As:"
        panel.beginSheetModal(for: self.view.window!) { (reply) in
            if reply == .OK, let importURL = panel.url {
                var segueID = "toBadFile"
                do {
                    let newData = try NSDictionary(contentsOf: importURL, error: ())   // try to coerce to NSDictionary
                    if let cn = newData["currentName"], newData[cn] != nil,
                        (newData["arrangements"] as? [String: Any])?.count ?? -1 == (newData["orderedArrangements"] as? [String])?.count ?? -2 { // is valid dictionary for DIM?
                        segueID = "toPlistOption"
                        self.newData = newData
                    }
                } catch { if #available(macOS 11.0, *) { Logger.diag.error("cast to NSDictionary failed in readPlist")} }
                self.performSegue(withIdentifier: segueID, sender: self)
            }
        }
    }
    func doPlistOption(_ plistOption : PlistOptions = .cancel) {    // replace, merge input to current, merge current into import or cancel
        if plistOption != .cancel && newData?["arrangements"] != nil {
            switch plistOption {
            case .mergeIntoCurrent:
                if let newArrangements = newData!["arrangements"] as? [String: Any] {
                    if #available(macOS 11.0, *) { Logger.diag.info(".mergIntoCurrent \(newArrangements.count) \(self.arrangements.count)") }
                    for (name, arrangement) in newArrangements {
                        if arrangements[name] == nil {
                            arrangements[name] = arrangement
                            orderedArrangements.append(name)
                        }
                    }
                }
            case .replace, .mergeIntoImported:
                currentName = newData?["currentName"] as? String ?? currentName
                restoreAtStart = newData?["restoreAtStart"] as? Bool ?? restoreAtStart
                quitAfterStart = newData?["quitAfterStart"] as? Bool ?? quitAfterStart
                orderedArrangements = newData?["orderedArrangements"] as? [String] ?? orderedArrangements
                automaticSave = newData?["automaticSave"] as? Bool ?? automaticSave
                timerSeconds = newData?["timerSeconds"] as? Int ?? timerSeconds
                if plistOption == .replace {
                    arrangements = newData!["arrangements"] as? [String: Any] ?? arrangements
                    if #available(macOS 11.0, *) { Logger.diag.info(".replace \(self.arrangements.count)") }
                } else {
                    if let newArrangements = newData!["arrangements"] as? [String: Any] {
                        for (name, arrangment) in newArrangements {
                            arrangements[name] = arrangment
                            if !orderedArrangements.contains(name) { orderedArrangements.append(name) }
                        }
                        if #available(macOS 11.0, *) { Logger.diag.info(".mergeIntoImported \(self.arrangements.count) \(newArrangements.count)") }
                    }
                }
            case .cancel: // should never reach, but compiler complains
                return
            }
            savePrefs()
            loadPrefs()
        }
        newData = nil
    }
}

import OSLog // let's do some logging
@available(macOS 11.0, *)
extension Logger {
    /// Using your bundle identifier is a great way to ensure a unique identifier.
    private static var subsystem = Bundle.main.bundleIdentifier!

    /// All logs related to tracking and analytics.
    static let diag = Logger(subsystem: subsystem, category: "info")
}
