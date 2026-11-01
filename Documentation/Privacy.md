# Roam Control Privacy

Roam Control is designed to keep sensitive location and pairing information on the iPhone.

## Information that stays on the iPhone

Roam Control does not send:

- Coordinates, selected places or addresses.
- Search text, favourites or location history.
- Walking routes, route progress or pace.
- Pairing records, pairing PINs or cryptographic material.
- Apple ID, device name or personal details.
- Full connection diagnostic reports or support reports.

Pairing records are stored in the device-only Keychain. App preferences, saved places, location history and routes remain in local app storage.

## No usage statistics

This build does not collect usage statistics and embeds no third-party analytics SDK. It sends no event, no installation identifier and no version or build beacon to any analytics service. There is no statistics switch to turn on, because nothing is collected.

The app's only outbound traffic is to the local iOS device over the developer tunnel, plus — only when the user asks for a version check — the public GitHub release API for the `FaHits/Roam-Control` repository.

## Changes

Any change to what leaves the device must be reflected in this document before release.
