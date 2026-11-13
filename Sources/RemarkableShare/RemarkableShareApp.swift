import AppKit
import RemarkableShareCore
import SwiftUI

@main
struct RemarkableShareApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var controller = TabletController()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(controller: controller)
        } label: {
            // The label is always alive, so it's where URL-scheme requests open windows.
            MenuBarIcon(controller: controller, systemName: menuIcon)
                .onAppear { appDelegate.controller = controller }
        }

        Window("reMarkable", id: "viewer") {
            ViewerWindow(controller: controller)
        }
        .defaultSize(width: 900, height: 1000)
        .defaultLaunchBehavior(.suppressed)

        Window("Set Up reMarkable Share", id: "setup") {
            SetupWindow(controller: controller)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }

    private var menuIcon: String {
        switch controller.state {
        case .streaming: return "rectangle.on.rectangle.circle.fill"
        case .failed: return "exclamationmark.triangle"
        case .noCable: return "rectangle.on.rectangle.slash"
        default: return "rectangle.on.rectangle"
        }
    }
}

private struct MenuBarIcon: View {
    let controller: TabletController
    let systemName: String
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: systemName)
            .onChange(of: controller.windowRequest) { _, request in
                guard let request else { return }
                openWindow(id: request.id)
                NSApp.activate()
            }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: TabletController?

    /// remarkable-share://share/usb · remarkable-share://share/wifi · remarkable-share://stop
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let controller, let url = urls.first, let action = URLAction(url) else { return }
        Task { @MainActor in
            switch action {
            case .share(let mode):
                controller.requestWindow("viewer")
                await controller.start(mode)
            case .stop:
                await controller.stop()
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let controller else { return .terminateNow }
        Task { @MainActor in
            await controller.shutdown()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
