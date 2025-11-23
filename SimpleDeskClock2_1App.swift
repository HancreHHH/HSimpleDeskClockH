import SwiftUI
import Combine

// MARK: - Shared Settings
class ClockSettings: ObservableObject {
    @Published var fontScale: CGFloat = 1.0
    @Published var isFrozen: Bool = false
}

// MARK: - Main App
@main
struct SimpleClockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            EmptyView() // Clock window handled by AppDelegate
        }
    }
}

// MARK: - AppDelegate for menu bar
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var clockWindow: NSWindow!
    var settings = ClockSettings()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Restore last window position if available
        let defaultFrame = NSRect(x: 100, y: 500, width: 400, height: 250)
        let savedFrameString = UserDefaults.standard.string(forKey: "clockWindowFrame")
        let frame = savedFrameString != nil ? NSRectFromString(savedFrameString!) : defaultFrame
        
        // Create the clock window
        let contentView = ContentView(settings: settings)
        clockWindow = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        clockWindow.contentView = NSHostingView(rootView: contentView)
        clockWindow.isOpaque = false
        clockWindow.backgroundColor = .clear
        clockWindow.level = .floating
        clockWindow.isMovableByWindowBackground = true
        clockWindow.hasShadow = false
        clockWindow.ignoresMouseEvents = false
        clockWindow.makeKeyAndOrderFront(nil)
        
        // Observe window moves to save position
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: clockWindow, queue: .main) { _ in
            let frameString = NSStringFromRect(self.clockWindow.frame)
            UserDefaults.standard.set(frameString, forKey: "clockWindowFrame")
        }

        // Create persistent popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 200, height: 260)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(settings: settings, clockWindow: clockWindow)
        )
        
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "🕒"
            button.action = #selector(togglePopover(_:))
        }
    }
    
    @objc func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}

// MARK: - Menu bar popover content
struct MenuBarView: View {
    @ObservedObject var settings: ClockSettings
    var clockWindow: NSWindow

    var body: some View {
        VStack(spacing: 10) {
            Text("Simple Clock").font(.headline)
            
            // Freeze / Unfreeze
            Button(action: toggleFreeze) {
                Text(settings.isFrozen ? "Unfreeze" : "Freeze")
            }
            .padding(5)
            .background(Color.gray.opacity(0.5))
            .cornerRadius(5)
            
            // Font scale slider
            VStack {
                Text("Scale: \(String(format: "%.2f", settings.fontScale))")
                    .font(.system(size: 12))
                Slider(value: $settings.fontScale, in: 0.5...2.0)
                    .onChange(of: settings.fontScale) { _ in
                        // Force clock view to refresh
                        clockWindow.contentView?.needsDisplay = true
                    }
            }
            .frame(width: 180)
            
            // Feedback button
            Button(action: openFeedback) {
                Text("Feedback")
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color.blue.opacity(0.7))
                    .cornerRadius(5)
            }
            
            // Quit button
            Button(action: quitApp) {
                Text("Quit")
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color.red.opacity(0.7))
                    .cornerRadius(5)
            }
            
            // Version text
            Text("v 2.1 by Henry H")
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .padding()
    }

    func toggleFreeze() {
        settings.isFrozen.toggle()
        if settings.isFrozen {
            clockWindow.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
            clockWindow.isMovableByWindowBackground = false
        } else {
            clockWindow.level = .floating
            clockWindow.isMovableByWindowBackground = true
        }
    }

    func openFeedback() {
        if let url = URL(string: "https://forms.gle/ignnbx8xVHA93BPy9") {
            NSWorkspace.shared.open(url)
        }
    }

    func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Clock ContentView
struct ContentView: View {
    @ObservedObject var settings: ClockSettings
    @State private var time = Date()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 15) {
            Text(formattedDate(date: time))
                .font(.system(size: 30 * settings.fontScale, weight: .heavy, design: .monospaced))
                .foregroundColor(.white)
                .textCase(.uppercase)
                .fixedSize(horizontal: true, vertical: false)
                .multilineTextAlignment(.center)
            
            Text(formattedTime(date: time))
                .font(.system(size: 90 * settings.fontScale, weight: .heavy, design: .monospaced))
                .foregroundColor(.white)
                .fixedSize(horizontal: true, vertical: false)
                .multilineTextAlignment(.center)
        }
        .padding(60)
        .background(Color.clear)
        .onReceive(timer) { value in time = value }
    }
    
    func formattedDate(date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEEE dd MMM"
        return df.string(from: date)
    }

    func formattedTime(date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: date)
    }
}
