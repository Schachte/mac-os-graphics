### Playground for internal Mac OS Graphics APIs

```bash
swiftc -o WindowsSpaceMonitor window-types.swift window-main.swift window-delegate.swift && \
sudo ./WindowsSpaceMonitor
```

#### Notes:

_Currently testing_

- Sonoma 14.5
  - Moving windows between spaces is not working
  - I can grab windows from other spaces
  - I can see other spaces and get the current space id + window ids
  - SIP is disabled (don't even think I need to for this API call)
  - Running a sudo

I can't get this private API to do anything, however, it seems like the alt-tab maintainer used this successfully:

- https://github.com/lwouis/alt-tab-macos/issues/1324#issuecomment-1120156153

-

```swift
CGSAddWindowsToSpaces(
    cgsMainConnectionId, windowsOnlyOnOtherSpaces as NSArray, [currentSpaceId])
```

I also tried the trick here from Amethyst:

- https://github.com/ianyh/Amethyst/pull/1184/files

```swift
CGSAddWindowsToSpaces(CGSMainConnectionID(), ids as CFArray, [spaceID] as CFArray)
        CGSRemoveWindowsFromSpaces(CGSMainConnectionID(), ids as CFArray, [currentSpace] as CFArray)
```

Output:

```
UUID: 37D8832A-2D66-02CA-B9F7-8F30A301B230
Current space ID: 5

CGSMainConnectionID: 647271
Other spaces found: [213]
Windows on current space: [115, 99, 98, 94, 26, 100, 25, 27, 24, 22, 38, 19331, 12159, 19316, 10, 116, 942, 12493, 13406]
Windows on other spaces: [13749, 18128, 13747, 116, 13328]
Windows to move: [13328, 13749, 18128, 13747]
Warning: Total failed moves: 4 windows
Unmoved window IDs: [13328, 13749, 18128, 13747]
UUID: 37D8832A-2D66-02CA-B9F7-8F30A301B230

Current space ID: 5
```
