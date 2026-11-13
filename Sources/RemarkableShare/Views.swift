import RemarkableShareCore
import ServiceManagement
import SwiftUI

// MARK: - Menu bar

struct MenuContent: View {
    @Bindable var controller: TabletController
    @Environment(\.openWindow) private var openWindow
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Text(controller.statusText)

        Divider()

        switch controller.state {
        case .streaming:
            Button("Show Viewer") { show("viewer") }.keyboardShortcut("v")
            Button("Stop Sharing") { Task { await controller.stop() } }.keyboardShortcut("s")
        case .needsSetup:
            Button("Set Up…") { show("setup") }
        case .failed:
            Button("Try Again (USB)") { startAndShow(.usb) }
            Button("Dismiss Error") { controller.dismissError() }
        default:
            Button("Share Screen (USB)") { startAndShow(.usb) }
                .keyboardShortcut("u")
                .disabled(controller.state != .ready)
            Button("Share Screen (Wi-Fi)") { startAndShow(.wifi) }
                .disabled(controller.state != .ready)
        }

        Divider()

        Toggle("Launch at Login", isOn: $launchAtLogin)
            .onChange(of: launchAtLogin) { _, on in
                do { try on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister() }
                catch { launchAtLogin = SMAppService.mainApp.status == .enabled }
            }
        Menu("Advanced") {
            Button("Re-run Setup…") { show("setup") }
            Button("Remove Streaming Tool from Tablet") { Task { await controller.uninstallFromTablet() } }
                .disabled(controller.state != .ready)
        }
        Button("Quit reMarkable Share") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }

    private func show(_ id: String) {
        openWindow(id: id)
        NSApp.activate()
    }

    private func startAndShow(_ mode: StreamMode) {
        show("viewer")
        Task { await controller.start(mode) }
    }
}

// MARK: - Viewer window

struct ViewerWindow: View {
    @Bindable var controller: TabletController
    @State private var reloadToken = 0

    var body: some View {
        Group {
            if let stream = controller.state.stream {
                StreamWebView(stream: stream, reloadToken: reloadToken)
            } else {
                StatusPanel(controller: controller)
            }
        }
        .frame(minWidth: 480, minHeight: 360)
        .toolbar {
            if controller.state.stream != nil {
                ToolbarItem {
                    Button { reloadToken += 1 } label: { Label("Reload", systemImage: "arrow.clockwise") }
                }
                ToolbarItem {
                    Button { Task { await controller.stop() } } label: { Label("Stop", systemImage: "stop.fill") }
                        .help("Stop sharing")
                }
            }
        }
        .navigationTitle("reMarkable — \(controller.statusText)")
        // Closing the viewer stops the stream so the tablet isn't left serving it.
        .onDisappear { Task { await controller.stop() } }
    }
}

private struct StatusPanel: View {
    @Bindable var controller: TabletController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 44)).foregroundStyle(.secondary)
            Text(controller.statusText).font(.title3)
            if controller.state.isBusy || controller.state == .checking { ProgressView() }
            HStack {
                switch controller.state {
                case .ready, .failed:
                    Button("Share over USB") { Task { await controller.start(.usb) } }.keyboardShortcut(.defaultAction)
                    Button("Share over Wi-Fi") { Task { await controller.start(.wifi) } }
                case .needsSetup:
                    Button("Set Up…") { openWindow(id: "setup") }.keyboardShortcut(.defaultAction)
                default: EmptyView()
                }
            }
            if controller.state == .noCable {
                Text("Connect the tablet to this Mac with its USB cable and wake it up.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var icon: String {
        switch controller.state {
        case .noCable: return "cable.connector.slash"
        case .failed: return "exclamationmark.triangle"
        case .needsSetup: return "key"
        default: return "ipad.landscape"
        }
    }
}

// MARK: - One-time setup

struct SetupWindow: View {
    @Bindable var controller: TabletController
    @Environment(\.dismiss) private var dismiss
    @State private var rootPassword = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connect to your reMarkable").font(.title2.bold())
            Text("This is needed once. Plug the tablet in with USB, then enter its root password.")
            GroupBox {
                Text("On the tablet: **Settings → Help → Copyrights and licenses**, scroll to **GPLv3 Compliance**. The password is shown there.")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            SecureField("Tablet root password", text: $rootPassword)
                .textFieldStyle(.roundedBorder)
                .onSubmit(connect)
            if let error { Text(error).foregroundStyle(.red) }
            Text("The password is used once to install a dedicated SSH key, then forgotten. It is not stored.")
                .font(.footnote).foregroundStyle(.secondary)
            HStack {
                Spacer()
                if busy { ProgressView().controlSize(.small) }
                Button("Cancel") { dismiss() }
                Button("Connect", action: connect)
                    .keyboardShortcut(.defaultAction)
                    .disabled(rootPassword.isEmpty || busy)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func connect() {
        guard !rootPassword.isEmpty, !busy else { return }
        busy = true
        error = nil
        Task {
            defer { busy = false }
            do {
                try await controller.completeSetup(rootPassword: rootPassword)
                rootPassword = ""
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
