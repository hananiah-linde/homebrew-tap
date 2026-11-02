# hananiah-linde/homebrew-tap

Homebrew casks for my small macOS utilities.

```sh
brew tap hananiah-linde/tap
brew trust --cask hananiah-linde/tap/<name>   # Homebrew only loads casks from trusted third-party taps
brew install --cask hananiah-linde/tap/<name>
```

| Cask | Description |
| --- | --- |
| [`alert`](https://github.com/hananiah-linde/alert) | Menu bar utility that shows Dock badges for chosen apps |
| [`awake`](https://github.com/hananiah-linde/awake) | Menu bar utility that prevents sleep |

## Releasing from this Mac

[`scripts/release-macos-app.sh`](scripts/release-macos-app.sh) does a full release locally, avoiding GitHub's macOS runner queue. Clone this repo next to the app repo (e.g. `~/dev/homebrew-tap` and `~/dev/awake`), then from the app repo:

```sh
../homebrew-tap/scripts/release-macos-app.sh <AppName> <cask>   # or `make release`
```

It reads `VERSION`, tags `v<VERSION>` if needed, builds from the tag with `UNIVERSAL=1`, signs with the keychain's Developer ID Application identity, notarizes, staples, publishes `<AppName>-<version>.zip` to a GitHub Release, and commits the new version and sha256 to `Casks/<cask>.rb`. `SKIP_PUBLISH=1` stops after stapling.

One-time setup on each Mac:

1. Install the Developer ID Application certificate in the login keychain (Xcode → Settings → Accounts → Manage Certificates).
2. Store notarization credentials under the profile name `notary`:
   ```sh
   xcrun notarytool store-credentials notary --key ~/path/AuthKey_XXXX.p8 --key-id <KEY_ID> --issuer <ISSUER_ID>
   ```
3. Be signed in with `gh` (for the release) and able to push to this repo (for the cask).

A new utility needs a `VERSION` file, a `scripts/build-app.sh` that produces `dist/<AppName>.app` signed with `$SIGN_IDENTITY` (`--options runtime --timestamp`), and `Casks/<cask>.rb` committed here before its first release.

## Release workflows (CI fallback)

These reusable GitHub Actions workflows do the same release in CI. Utilities call them from a manually run workflow on a `vX.Y.Z` tag:

- [`release-macos-app.yml`](.github/workflows/release-macos-app.yml): builds the app, signs it with a Developer ID certificate, notarizes and staples it, then attaches `<App>-<version>.zip` to a GitHub Release.
- [`bump-cask.yml`](.github/workflows/bump-cask.yml): updates `version` and `sha256` in `Casks/<name>.rb` and pushes to `main`.

Usage examples are at the top of each file. The calling repo needs these secrets:

| Secret | What it is |
| --- | --- |
| `DEVELOPER_ID_P12_BASE64` | Base64 of the Developer ID Application certificate + private key, exported as .p12 |
| `DEVELOPER_ID_P12_PASSWORD` | Password set when exporting the .p12 |
| `NOTARY_API_KEY` | Contents of the App Store Connect API key file (`AuthKey_XXXX.p8`) |
| `NOTARY_API_KEY_ID` | That key's ID |
| `NOTARY_API_ISSUER_ID` | App Store Connect issuer ID |
| `APPLE_ID` | Apple ID email (used for notarization when `NOTARY_API_KEY` isn't set) |
| `APPLE_TEAM_ID` | 10-character team ID from developer.apple.com → Account → Membership details |
| `APPLE_APP_PASSWORD` | App-specific password from account.apple.com → Sign-In and Security |
| `TAP_GITHUB_TOKEN` | Fine-grained token with Contents read/write on this repo only |

Notarization needs either the three `NOTARY_API_*` secrets or the three `APPLE_*` ones; the API key wins when both are set.

A new utility needs `Casks/<name>.rb` committed here before its first release; after that the version and sha256 update automatically.
