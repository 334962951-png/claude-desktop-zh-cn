# Changelog

All notable changes to this project will be documented in this file.

## [1.9659.4] - 2026-06-02

### Changed

- Synced language resources to Claude Desktop `1.9659.4.0`
- Re-extracted the installed app resources from `Claude_1.9659.4.0_x64__pzs8sxrjxfjjc`
- Rebuilt `translated-zh-CN/` against the new `en-US` baseline while preserving existing translations
- Archived the previous active update artifacts for `1.8555.0` into `archive/updates/`
- Updated the installer to patch the runtime i18n merge order so local `zh-CN` messages win over bootstrap `gated_messages`
- Updated the installer to support the new compiled language array structure used by `1.9659.4.0`
- Updated the installer to preserve and target the original user `LOCALAPPDATA` path after elevation
- Added verification screenshots under `docs/screenshots/`
- Refreshed the project documentation for a formal release layout

### Translation Status

- `ion-dist`: `15209` entries
- `desktop-shell`: `397` entries
- `statsig`: `46` entries
- New `ion-dist` entries translated this round: `821`
- Remaining intentional English fallback entries in `ion-dist`: `4`
- Remaining new untranslated `desktop-shell` entries: `0`

### Verified

- Home page Chinese UI verified in-app
- Settings menu Chinese UI verified in-app
- Settings page core labels verified in-app

## [1.8555.0] - 2026-05-28

### Added

- Added a formal Git repository structure under `D:\claude-desktop-zh-cn`
- Added `LICENSE`, `.gitattributes`, and expanded `.gitignore`
- Added `update-1.8555.0-summary.json` for the current release
- Added `new-ion-dist-keys-1.8555.0.txt` to track untranslated new entries
- Added 3 translated `desktop-shell` keys introduced in `1.8555.0.0`
- Added all 781 translated `ion-dist` new entries introduced by Claude Desktop `1.8555.0.0`

### Changed

- Updated the language pack baseline from Claude Desktop `1.8089.1.0` to `1.8555.0.0`
- Rebuilt `translated-zh-CN/` from the latest extracted `en-US` resources
- Updated `README.md` to reflect the active version and formal project structure
- Moved historical backups and old update artifacts into `archive/`
- Renamed the default Git branch to `main`

### Translation Status

- `ion-dist`: `14648` entries
- `desktop-shell`: `373` entries
- `statsig`: `46` entries
- Remaining new untranslated `ion-dist` entries: `0`

## [1.8089.1] - 2026-05-21

### Changed

- Synced language resources to Claude Desktop `1.8089.1.0`
- Preserved historical update summary in `archive/updates/update-1.8089.1-summary.json`
