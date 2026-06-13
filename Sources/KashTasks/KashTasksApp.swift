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

    init() {
        let store = TaskStore(fileURL: AppPaths.tasksFile)
        _store = StateObject(wrappedValue: store)
        _scheduler = StateObject(wrappedValue: ReminderScheduler(store: store))
    }

    var body: some Scene {
        MenuBarExtra("KashTasks", systemImage: "checklist") {
            MenuBarView()
                .environmentObject(store)
                .onAppear { scheduler.start() }
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { granted, error in
            if let error { NSLog("KashTasks: notif auth error \(error)") }
            NSLog("KashTasks: notifications granted=\(granted)")
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
