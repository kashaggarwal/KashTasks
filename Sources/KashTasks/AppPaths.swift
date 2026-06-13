import Foundation

enum AppPaths {
    static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("KashTasks", isDirectory: true)
    }

    static var tasksFile: URL {
        supportDirectory.appendingPathComponent("tasks.json")
    }
}
