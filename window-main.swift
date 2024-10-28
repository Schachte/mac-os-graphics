import Cocoa

@main
struct MainApp {
  static func main() {
    WindowManager.refreshAllIdsAndIndexes()
    WindowManager.refreshCurrentSpaceId()
    WindowManager.addInitialRunningApplicationsWindows()
  }
}
