# Development Notes

Parcelite is a compact macOS SwiftUI app for tracking parcels through Ship24.

## Architecture

- `Sources/Parcelite` contains the macOS app entry point and SwiftUI views.
- `Sources/ParceliteCore` contains models, persistence, Keychain access, notifications, validation, and the Ship24 client.
- `Tests/ParceliteCoreTests` covers parsing, milestone mapping, package persistence, API-key migration, duplicate handling, and Keychain behavior.

## Persistence

Parcel data is stored as JSON in `UserDefaults` under the `packages.v1` key for the `com.oliwer.parcelite` app domain.

The Ship24 API key is stored in macOS Keychain under the `com.oliwer.parcelite` service. On first launch after upgrading from PaczkoMeter, Parcelite copies existing `packages.v1` data from the old `com.oliwer.paczkometer` preferences domain when the new domain has no package data. It also migrates a legacy `ship24ApiKey` preference into Keychain and removes the plain preference value.

## Ship24

Parcelite uses `POST https://api.ship24.com/public/v1/trackers/track` with a bearer token and request body `{"trackingNumber":"..."}`. The first lookup for a new number can be slower because Ship24 may query carrier systems synchronously.

The default automatic refresh interval is 5 minutes. If users encounter HTTP 429 errors, increase the interval or refresh manually until the Ship24 quota resets.

## Release Build

Run:

```bash
make app
```

The script builds a release binary, creates `dist/Parcelite.app`, applies ad-hoc signing, and writes `dist/Parcelite-0.1.0-macOS.zip`.

Developer ID signing and notarization are intentionally out of scope for the first public release.
