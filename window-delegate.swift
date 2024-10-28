import Cocoa

typealias CGSWindowID = UInt32
typealias SpaceIndex = Int
typealias ScreenUuid = CFString

class WindowManager {
  private let connection: CGSConnectionID
  static var currentSpaceId = CGSSpaceID(1)
  static var currentSpaceIndex = SpaceIndex(1)
  static var visibleSpaces = [CGSSpaceID]()
  static var screenSpacesMap = [ScreenUuid: [CGSSpaceID]]()
  static var idsAndIndexes = [(CGSSpaceID, SpaceIndex)]()

  init() {
    self.connection = CGSMainConnectionID()
  }

  static func refreshCurrentSpaceId() {
    if let mainScreen = NSScreen.main,
      let uuid = mainScreen.uuid()
    {
      print("UUID: \(uuid)")
      currentSpaceId = CGSManagedDisplayGetCurrentSpace(CGSMainConnectionID(), uuid)
      print("Current space ID: \(currentSpaceId)")
      print(currentSpaceId)
    }
  }

  static func updateCurrentSpace() {
    refreshCurrentSpaceId()
    currentSpaceIndex =
      idsAndIndexes.first { (spaceId: CGSSpaceID, _) -> Bool in
        spaceId == currentSpaceId
      }?.1 ?? SpaceIndex(1)
  }

  static func refreshAllIdsAndIndexes() {
    idsAndIndexes.removeAll()
    screenSpacesMap.removeAll()
    visibleSpaces.removeAll()
    var spaceIndex = SpaceIndex(1)
    (CGSCopyManagedDisplaySpaces(CGSMainConnectionID()) as! [NSDictionary]).forEach {
      (screen: NSDictionary) in
      var display = screen["Display Identifier"] as! ScreenUuid
      if display as String == "Main", let mainUuid = NSScreen.main?.uuid() {
        display = mainUuid
      }
      (screen["Spaces"] as! [NSDictionary]).forEach { (space: NSDictionary) in
        let spaceId = space["id64"] as! CGSSpaceID
        idsAndIndexes.append((spaceId, spaceIndex))
        screenSpacesMap[display, default: []].append(spaceId)
        spaceIndex += 1
      }
      visibleSpaces.append((screen["Current Space"] as! NSDictionary)["id64"] as! CGSSpaceID)
    }
  }

  static func otherSpaces() -> [CGSSpaceID] {
    return idsAndIndexes.filter { $0.0 != currentSpaceId }.map { $0.0 }
  }

  static func getWindowsInSpace(_ spaceIds: [CGSSpaceID], _ includeInvisible: Bool = true)
    -> [CGWindowID]
  {
    var set_tags = ([] as CGSCopyWindowsTags).rawValue
    var clear_tags = ([] as CGSCopyWindowsTags).rawValue
    var options = [.screenSaverLevel1000] as CGSCopyWindowsOptions
    if includeInvisible {
      options = [options, .invisible1, .invisible2]
    }
    return CGSCopyWindowsWithOptionsAndTags(
      CGSMainConnectionID(), 0, spaceIds as CFArray, options.rawValue, &set_tags, &clear_tags)
      as! [CGWindowID]
  }

  static func windowsInSpaces(_ spaceIds: [CGSSpaceID], _ includeInvisible: Bool = true)
    -> [CGWindowID]
  {
    var set_tags = ([] as CGSCopyWindowsTags).rawValue
    var clear_tags = ([] as CGSCopyWindowsTags).rawValue
    var options = [.screenSaverLevel1000] as CGSCopyWindowsOptions
    if includeInvisible {
      options = [options, .invisible1, .invisible2]
    }
    return CGSCopyWindowsWithOptionsAndTags(
      cgsMainConnectionId, 0, spaceIds as CFArray, options.rawValue, &set_tags, &clear_tags)
      as! [CGWindowID]
  }

  static func addInitialRunningApplicationsWindows() {
    if !AXIsProcessTrusted() {
      print(
        "The application is not trusted. Please grant accessibility permissions in System Preferences."
      )
      return
    }
    let cgsMainConnectionId = CGSMainConnectionID()
    print("CGSMainConnectionID: \(cgsMainConnectionId)")
    let otherSpaces = [UInt64(213)]
    print("Other spaces found: \(otherSpaces)")

    guard otherSpaces.count > 0 else {
      print("No other spaces found")
      return
    }

    let windowsOnCurrentSpace = getWindowsInSpace([currentSpaceId])
    print("Windows on current space: \(windowsOnCurrentSpace)")

    let windowsOnOtherSpaces = getWindowsInSpace(otherSpaces)
    print("Windows on other spaces: \(windowsOnOtherSpaces)")

    let windowsOnlyOnOtherSpaces = Array(
      Set(windowsOnOtherSpaces).subtracting(windowsOnCurrentSpace))
    print("Windows to move: \(windowsOnlyOnOtherSpaces)")

    guard windowsOnlyOnOtherSpaces.count > 0 else {
      print("No windows to move")
      return
    }

    CGSAddWindowsToSpaces(
      cgsMainConnectionId, windowsOnlyOnOtherSpaces as NSArray, [currentSpaceId])
    let windowsStillOnOtherSpaces = getWindowsInSpace(otherSpaces)
    let unmovedInChunk = windowsOnlyOnOtherSpaces.filter { windowsStillOnOtherSpaces.contains($0) }

    // Final verification
    let finalWindowsOnOtherSpaces = getWindowsInSpace(otherSpaces)
    let totalUnmoved = windowsOnlyOnOtherSpaces.filter { finalWindowsOnOtherSpaces.contains($0) }
    if totalUnmoved.count > 0 {
      print("Warning: Total failed moves: \(totalUnmoved.count) windows")
      print("Unmoved window IDs: \(totalUnmoved)")
    }

    // Refresh space data
    refreshAllIdsAndIndexes()
    refreshCurrentSpaceId()
  }

  static func moveWindowsToSpace(windowIDs: [CGWindowID], targetSpace: CGSSpaceID) {
    if !AXIsProcessTrusted() {
      print(
        "The application is not trusted. Please grant accessibility permissions in System Preferences."
      )
      return
    }

    let windowNumbers = windowIDs.map { NSNumber(value: $0) }
    print(windowNumbers)

    CGSMoveWindowsToManagedSpace(CGSMainConnectionID(), windowNumbers as CFArray, targetSpace)
    // Verify the move
    if let currentSpaces = CGSCopySpacesForWindows(
      CGSMainConnectionID(), CGSSpaceMask.all.rawValue, windowNumbers as CFArray) as? [CGSSpaceID]
    {
      print("Windows are now in spaces:", currentSpaces)
      if !currentSpaces.contains(targetSpace) {
        print("Failed to move windows to the target space.")
      }
    } else {
      print("Failed to retrieve current spaces for windows.")
    }
  }

  static func canMoveWindow(_ windowId: CGWindowID) -> Bool {
    var level: CGWindowLevel = 0
    let result = CGSGetWindowLevel(CGSMainConnectionID(), windowId, &level)

    guard result.rawValue == 0 else {
      print("Failed to get window level for window \(windowId)")
      return false
    }

    if level == 0 {
      return true
    }

    if level != 0 {
      return false
    }
    print("Window \(windowId) has level: \(level)")

    let spaces =
      CGSCopySpacesForWindows(
        CGSMainConnectionID(),
        CGSSpaceMask.current.rawValue,
        [windowId] as CFArray) as! [CGSSpaceID]

    for space in spaces {
      if CGSSpaceGetType(CGSMainConnectionID(), space) == .fullscreen {
        print("Window \(windowId) is in fullscreen space")
        return false
      }
    }

    return true
  }
}

extension NSScreen {
  func uuid() -> ScreenUuid? {
    if let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")],
      // these APIs implicitly unwrap their return values, but it can actually be nil thus we check
      let screenUuid = CGDisplayCreateUUIDFromDisplayID(screenNumber as! UInt32),
      let uuid = CFUUIDCreateString(nil, screenUuid.takeRetainedValue())
    {
      return uuid
    }
    return nil
  }
}
