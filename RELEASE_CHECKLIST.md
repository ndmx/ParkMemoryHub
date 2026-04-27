# Park Memory Hub Release Checklist

Last updated: April 26, 2026

## Must Do Before TestFlight or App Review

- Deploy the CloudKit schema for `iCloud.lxr.ParkMemoryHub` to the production environment
- Verify the production schema includes:
  - `GroupSyncEvent`
  - `MemoryMediaAsset`
  - the current fields used by the app
- Confirm the app works with production CloudKit, not only development CloudKit
- Publish a public Privacy Policy URL
- Publish a public Support URL
- Complete App Store Connect privacy answers for the real app behavior
- Review all user-facing copy for production wording
- Archive a Release build and upload it to App Store Connect

## Privacy Items To Review In App Store Connect

Based on the current app behavior, review whether you need to disclose:

- User ID
- Precise or coarse location
- Photos or videos shared through memories
- Other user content such as captions, notes, tags, planner content, and profile photo

Use Apple's latest App Privacy guidance when filling this out.

## TestFlight Pass

Test on at least:

- two physical iPhones
- different Apple IDs
- one brand-new circle
- one joined circle

Verify:

- create and share memory
- memory appears on second device
- planner item visibility works for Circle, Some Members, and Only Me
- radar sharing turns on and off correctly
- join flow works from invite link
- leave circle moves the device into a new circle

## Product Metadata

- App name
- Subtitle
- Description
- Keywords
- Category
- Age rating
- Support URL
- Privacy Policy URL
- Screenshots for required device sizes
- App Review notes that explain the circle invite flow and iCloud/CloudKit dependency

## Versioning

- Set the release version
- Increment build number before each upload

## Recommended App Review Notes

Suggested starting point:

> Park Memory Hub is a group trip app for families and friends. Users create or join a circle, then share memories, plans, and optional location updates through iCloud/CloudKit. To test group features, create a circle on one device, share the invite link from Profile, open it on a second device, and accept the invite inside the app.
