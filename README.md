# hananiah-linde/homebrew-tap

Homebrew casks for my small macOS utilities.

```sh
brew install --cask hananiah-linde/tap/<name>
```

| Cask | Description |
| --- | --- |
| [`awake`](https://github.com/hananiah-linde/awake) | Menu bar utility that prevents sleep |

## Release workflows

This repo also hosts reusable GitHub Actions workflows that each utility's repo calls on a `vX.Y.Z` tag push:

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
| `TAP_GITHUB_TOKEN` | Fine-grained token with Contents read/write on this repo only |

A new utility needs `Casks/<name>.rb` committed here before its first release; after that the version and sha256 update automatically.
