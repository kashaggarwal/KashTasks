import SwiftUI
import AppKit
import UserNotifications
import ServiceManagement
import KashTasksCore

@main
struct KashTasksApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store: TaskStore
    @StateObject private var scheduler: ReminderScheduler

    private let notifications: NotificationManager
    private let quickCapture: QuickCaptureController

    init() {
        let store = TaskStore(fileURL: AppPaths.tasksFile)
        _store = StateObject(wrappedValue: store)

        let scheduler = ReminderScheduler(store: store)
        _scheduler = StateObject(wrappedValue: scheduler)

        let notifications = NotificationManager(store: store)
        self.notifications = notifications
        let quickCapture = QuickCaptureController(store: store)
        self.quickCapture = quickCapture

        // Start subsystems (init runs on the main actor for a SwiftUI App).
        scheduler.start()
        notifications.register()
        HotkeyManager.shared.register { quickCapture.show() }
    }

    var body: some Scene {
        MenuBarExtra("KashTasks", systemImage: "checklist") {
            MenuBarView()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)

        Window("KashTasks Dashboard", id: "dashboard") {
            DashboardView()
                .environmentObject(store)
        }
        .defaultSize(width: 720, height: 580)
        .windowResizability(.contentMinSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound])
                NSLog("KashTasks: notifications granted=\(granted)")
            } catch {
                NSLog("KashTasks: notif auth error \(error)")
            }
        }

        do {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("KashTasks: login-item registration failed: \(error)")
        }
    }
}
