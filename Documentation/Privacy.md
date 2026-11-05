# Roam Control Privacy

Roam Control is designed to keep sensitive location and pairing information on the iPhone.

## Information that stays on the iPhone

Roam Control does not send:

- Coordinates, selected places or addresses.
- Search text, favourites or location history — apart from the search terms
  described under "Network traffic" below.
- Walking routes, route progress or pace.
- Pairing records, pairing PINs or cryptographic material.
- Apple ID, device name or personal details.
- Full connection diagnostic reports or support reports.

Pairing records are stored in the device-only Keychain. App preferences, saved places, location history and routes remain in local app storage.

## No usage statistics

This build does not collect usage statistics and embeds no third-party analytics SDK. It sends no event, no installation identifier and no version or build beacon to any analytics service. There is no statistics switch to turn on, because nothing is collected.

Apart from the developer tunnel to the local iOS device, two requests can leave the phone:

- The public GitHub release API for the `FaHits/Roam-Control` repository, only when the user
  asks for a version check.
- The current search term, only while "Search places outside China" is on and the typed
  query is at least three characters long. The term goes to
  `nominatim.openstreetmap.org` and nothing else is sent with it — no account, no identifier,
  no device name, no coordinates. The app never stores a search history and sends no
  analytics. Turning the setting off stops the requests.

Overseas place data © OpenStreetMap contributors, available under the ODbL.

## Changes

Any change to what leaves the device must be reflected in this document before release.
