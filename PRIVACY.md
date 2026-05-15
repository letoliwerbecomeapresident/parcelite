# Privacy

Parcelite is a local macOS app. It has no Parcelite account system and no analytics.

## Stored Locally

Parcelite stores these values on your Mac:

- Package labels
- Tracking numbers
- Latest status milestone
- Recent tracking events returned by Ship24
- Last refresh time and last error

Package data is stored in macOS preferences for `com.oliwer.parcelite`. The Ship24 API key is stored in macOS Keychain.

## Sent to Ship24

When Parcelite refreshes a package, it sends the tracking number to Ship24 over HTTPS and authenticates with your Ship24 API key. Ship24 returns carrier, status, and event data.

Parcelite does not send package data to any other backend in version 0.1.0.

## Migration

On first launch after upgrading from PaczkoMeter, Parcelite can copy package data from the old `com.oliwer.paczkometer` preferences domain and migrate a legacy plain `ship24ApiKey` preference into Keychain. The plain API-key preference is removed after migration.
