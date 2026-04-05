import Cocoa
import Foundation

// Usage: ./wooby-hotkey <modifiers_mask> <keycode> <script_path>
// modifiers_mask: cmd=1048576, shift=131072, option=524288, ctrl=262144
// Ex: ./wooby-hotkey 393216 40 /path/to/voice-flow.sh  (ctrl+shift+k)

let arguments = CommandLine.arguments
if arguments.count < 4 {
    print("Usage: wooby-hotkey <modifiers_mask> <keycode> <script_path>")
    exit(1)
}

let targetModifiers = UInt64(arguments[1]) ?? 0
let targetKeyCode = CGKeyCode(arguments[2]) ?? 0
let scriptPath = arguments[3]
let pidFile = "/tmp/wooby-recording.pid"

print("Wooby Native Toggle Listener (CGEventTap) started.")
print("Monitoring KeyCode: \(targetKeyCode), Modifiers Mask: \(targetModifiers)")

var isProcessing = false

func myEventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if type == .keyDown {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let modifiers = event.flags.rawValue
        
        let currentMods = modifiers & (UInt64(CGEventFlags.maskCommand.rawValue) | 
                                      UInt64(CGEventFlags.maskShift.rawValue) | 
                                      UInt64(CGEventFlags.maskAlternate.rawValue) | 
                                      UInt64(CGEventFlags.maskControl.rawValue))
        
        if keyCode == Int64(targetKeyCode) && currentMods == targetModifiers {
            if isProcessing {
                print("[\(Date())] Already processing. Ignoring.")
                fflush(stdout)
                return nil
            }
            
            isProcessing = true
            let isRecording = FileManager.default.fileExists(atPath: pidFile)
            let action = isRecording ? "--stop" : "--start"
            
            print("[\(Date())] Match! Action: \(action)")
            fflush(stdout)
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptPath, action]
            
            process.terminationHandler = { _ in
                isProcessing = false
            }
            
            try? process.run()
            return nil
        }
    }
    return Unmanaged.passRetained(event)
}

guard let eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                      place: .headInsertEventTap,
                                      options: .defaultTap,
                                      eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
                                      callback: myEventTapCallback,
                                      userInfo: nil) else {
    print("Error: Could not create Event Tap. (Needs Accessibility Permissions)")
    exit(1)
}

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: eventTap, enable: true)

CFRunLoopRun()
