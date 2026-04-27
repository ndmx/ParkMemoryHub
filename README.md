# ParkMemory Hub

ParkMemory Hub is an iOS app for small groups who want to collect trip memories, coordinate plans, and find each other during a park visit.

The current app is Apple-first and local-first. Each device creates its own identity and circle on first launch. People join a shared circle through an invite link or invite code, and group updates sync through CloudKit.

## Features

- Memories: create photo memories with captions, tags, and optional locations.
- Radar: share your location with your circle and open member coordinates in Maps.
- Planner: create plans, add optional times and places, vote as a group, and update plan status.
- Profile: set your name and profile photo, start or join a circle, share invites, and run manual sync.
- Sync: memories, planner updates, and radar updates sync through CloudKit, with manual iCloud sync available as a fallback.

## Architecture

```text
ParkMemoryHub/
  Core/
    Domain/          App domain models
    Repositories/    File-backed and in-memory persistence
    Services/        CloudKit sync services
  Features/
    ParkHub/         Root tab shell and invite handling
    Memories/        Memory list, creation, detail, and sync
    Radar/           Member location sharing and map handoff
    Planner/         Plans, votes, status, and sync
    Profile/         Identity, circle invites, and settings
```

## Requirements

- iOS 18.0+
- Xcode with iOS device support
- Apple Developer account with iCloud/CloudKit capability enabled for `lxr.ParkMemoryHub`

## Build

Open `ParkMemoryHub.xcodeproj` in Xcode, select the `ParkMemoryHub` scheme, choose a connected iPhone, and run.

From the command line:

```sh
xcodebuild -project ParkMemoryHub.xcodeproj -scheme ParkMemoryHub -configuration Debug -destination 'generic/platform=iOS' build
```

## Sync Model

- Every device has a unique `DeviceIdentity` with a unique member id and circle id.
- Starting a new circle creates a new circle UUID.
- Joining a circle stores the invite's circle id on that device.
- CloudKit stores group sync events keyed by circle id.
- Devices pull and apply only events for their current circle.

## Privacy

Location sharing is opt-in. The app stores its working data locally and uses CloudKit for circle sync. There is no third-party backend dependency in the current app.

Release prep documents:

- [Release checklist](./RELEASE_CHECKLIST.md)
- [Privacy policy draft](./docs/PRIVACY_POLICY.md)
- [Support page draft](./docs/SUPPORT.md)
