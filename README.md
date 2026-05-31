# ParkMemory Hub

ParkMemory Hub is an iOS app for small groups who want to collect trip memories, coordinate plans, and find each other during a park visit.

The current app is Apple-first and local-first. Each device creates its own identity and circle on first launch. The circle's creator hosts it as a CloudKit shared zone in their private database; other people join by tapping an iCloud share link, and group updates sync through that shared zone.

## Features

- Memories: create photo memories with captions, tags, and optional locations.
- Radar: share your location with your circle and open member coordinates in Maps.
- Planner: create plans, add optional times and places, vote as a group, and update plan status.
- Profile: set your name and profile photo, start a circle, invite people (and manage or remove participants), and run manual sync.
- Sync: memories, planner updates, and radar updates sync through a CloudKit shared zone, with manual iCloud sync available on demand.

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

- Every device has a unique `DeviceIdentity` recording its member id, circle id, role (owner or participant), and the circle's CloudKit zone.
- Starting a circle provisions a custom CloudKit zone in the creator's private database, with a root `Circle` record and a `CKShare`.
- Inviting someone shares that `CKShare` link; accepting it joins the device as a read-write participant via their shared database.
- Members, memories (with photo assets), and plans sync as individual `CKRecord`s in the zone, fetched as deltas using a persisted server change token.
- Membership and read/write access are enforced by the CloudKit server. The owner can remove a participant to revoke access.

## Privacy

Location sharing is opt-in, and a member's last known location is stored in a CloudKit field-level encrypted value. Circle data lives in the owner's private/shared CloudKit databases — only invited participants can read it, and there is no public database or third-party backend. The app keeps a local-first copy of its working data on each device.

Release prep documents:

- [Release checklist](./RELEASE_CHECKLIST.md)
- [Privacy policy draft](./docs/PRIVACY_POLICY.md)
- [Support page draft](./docs/SUPPORT.md)
