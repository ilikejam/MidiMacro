import Cocoa
import CoreGraphics
import CoreMIDI

// Find bundle IDs with:
// /usr/libexec/PlistBuddy -c 'print CFBundleIdentifier' /Applications/<Application>.app/Contents/Info.plist
enum AppBundle: String {
    case emacs = "org.gnu.Emacs"
    case iterm = "com.googlecode.iterm2"
    case firefox = "org.mozilla.firefox"
    case slack = "com.tinyspeck.slackmacgap"
    case outlook = "com.microsoft.Outlook"
    case teams = "com.microsoft.teams2"
    case spotify = "com.spotify.client"
}

func handleMIDIKeyDown(_ id: UInt8) {
    print("Handling key \(id)")
    // Location comments are for Korg nanoPAD2 button locations
    switch id {
    case 37: // top, 1st
        print("Opening iTerm2")
        openApp(.iterm)
    case 39: // top, 2nd
        print("Opening Emacs")
        openApp(.emacs)
    case 41: // top, 3rd
        print("Opening Firefox")
        openApp(.firefox)
    case 43: // top, 4th
        print("Opening Slack")
        openApp(.slack)
    case 45: // top, 5th
        print("Opening Outlook")
        openApp(.outlook)
    case 47: // top, 6th
        print("Opening Teams")
        openApp(.teams)
    case 49: // top, 7th
        print("Opening Spotify")
        openApp(.spotify)
    case 36: // bottom, 1st
        print("Typing sudo su -")
        typeString("sudo su -\n")
    case 38: // bottom, 2nd
        print("Typing git checkout -b ")
        typeString("git checkout -b ")
    case 40: // bottom, 3rd
        print("Typing git add -A && git commit -m \"\"")
        typeString("git add -A && git commit -m \"\"")
    case 42: // bottom, 4th
        print("Typing slam")
        typeString("slam\n")
    case 44: // bottom, 5th
        print("Opening Google")
        openURL("https://www.google.com")
    case 46: // bottom, 6th
        print("Opening GitHub")
        openURL("https://github.com")
    case 48: // bottom, 7th
        print("Opening ChatGPT")
        openURL("https://chatgpt.com")
    default:
        break
    }
}

if #unavailable(macOS 11.0) {
    // MIDIInputPortCreateWithProtocol needs >=11.0
    print("Requires MacOS >= 11.0")
    exit(1)
}

func typeString(_ text: String) {
    guard let source = CGEventSource(stateID: .hidSystemState) else {
        print("Warning: Could not get CGEventSource")
        return
    }
    let utf16 = Array(text.utf16)
    for codeUnit in utf16 {
        var char = codeUnit
        guard let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: 0,
            keyDown: true
        ) else {
            print("Warning: Could not generate keyDown CGEvent")
            return
        }
        keyDown.keyboardSetUnicodeString(
            stringLength: 1,
            unicodeString: &char
        )
        guard let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: 0,
            keyDown: false
        ) else {
            print("Warning: Could not generate keyUp CGEvent")
            return
        }
        keyUp.keyboardSetUnicodeString(
            stringLength: 1,
            unicodeString: &char
        )
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

// openApp opens and/or brings to the front the given App
func openApp(_ app: AppBundle) {
    guard
        let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: app.rawValue
        )
    else {
        print("Warning: Could find app bundle \(app.rawValue)")
        return
    }
    let configuration = NSWorkspace.OpenConfiguration()
    NSWorkspace.shared.openApplication(
        at: url,
        configuration: configuration,
        completionHandler: nil
    )
}

func openURL(_ address: String) {
    guard let url = URL(string: address) else {
        return
    }
    NSWorkspace.shared.open(url)
}

func connectAllSources() {
    let sourceCount = MIDIGetNumberOfSources()
    for index in 0..<sourceCount {
        let source = MIDIGetSource(index)
        var name: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(source, kMIDIPropertyName, &name)
        let sourceName =
            name?.takeRetainedValue() ?? "Unknown @ \(index)" as CFString
        print("Connecting to source \(index): \(sourceName)")
        let connStatus = MIDIPortConnectSource(inputPort, source, nil)
        if connStatus != noErr {
            print("Warning: MIDIPortConnectSource failed for source \(sourceName)")
        }
    }
}

var client = MIDIClientRef()
var inputPort = MIDIPortRef()

let clientStatus = MIDIClientCreateWithBlock(
    "MidiListenerClient" as CFString,
    &client
) { messagePtr in
    let message = messagePtr.pointee
    switch message.messageID {
    case .msgObjectAdded:
        connectAllSources()
    default:
        break
    }
}
guard clientStatus == noErr else {
    print("Error: MIDIClientCreateWithBlock failed with \(clientStatus)")
    exit(1)
}

let portStatus = MIDIInputPortCreateWithProtocol(
  client,
  "MidiListener" as CFString,
  MIDIProtocolID._1_0,
  &inputPort
) { eventListUnsafePtr, _ in
    for midiEventPacket in eventListUnsafePtr.unsafeSequence() {
        let words = MIDIEventPacket.WordCollection(midiEventPacket)
        var statusStr = ""
        words.forEach { word in
            guard word > 0 else { return }
            let status = UInt8((word & 0x00FF_0000) >> 16)
            let key = UInt8((word & 0x0000_FF00) >> 8)
            let value = UInt8(word & 0x0000_00FF)
            statusStr = "\(status)"
            print("status \(statusStr), key \(key), value \(value)")
            switch status {
            case 144:
                handleMIDIKeyDown(key)
            default:
                break
            }
        }
    }
}
guard portStatus == noErr else {
    print("Error: MIDIInputPortCreateWithProtocol failed with \(portStatus)")
    exit(1)
}

connectAllSources()
print("Listening for MIDI input...")
RunLoop.current.run()
