#!/usr/bin/env bash
# Release a macOS app from this Mac: build from the vX.Y.Z tag, sign with Developer ID, notarize,
# staple, zip, publish a GitHub Release, and bump the cask in this tap.
#
# Run from the app repo's root:
#   ../homebrew-tap/scripts/release-macos-app.sh <AppName> <cask>
#
# The version comes from the app repo's VERSION file. If tag vVERSION doesn't exist yet it's
# created at HEAD (pushed only after notarization succeeds). The app repo's build command must
# produce dist/<AppName>.app, signing with $SIGN_IDENTITY using --options runtime --timestamp.
#
# One-time setup: store notarization credentials in the keychain (see NOTARY_PROFILE):
#   xcrun notarytool store-credentials notary --key AuthKey_XXXX.p8 --key-id <id> --issuer <issuer>
#
# Environment:
#   NOTARY_PROFILE   keychain profile from `notarytool store-credentials` (default: notary)
#   SIGN_IDENTITY    codesign identity (default: the Developer ID Application identity in the keychain)
#   BUILD_COMMAND    default: ./scripts/build-app.sh (run with UNIVERSAL=1, BUILD, SIGN_IDENTITY)
#   BUILD            CFBundleVersion (default: commit count at the tag)
#   SKIP_PUBLISH=1   build, notarize, and staple only; no tag push, release, or cask bump
set -euo pipefail

if [ $# -ne 2 ]; then
    echo "usage: $0 <AppName> <cask>" >&2
    exit 64
fi
APP_NAME="$1"
CASK="$2"

TAP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_REPO="$(pwd)"
NOTARY_PROFILE="${NOTARY_PROFILE:-notary}"
BUILD_COMMAND="${BUILD_COMMAND:-./scripts/build-app.sh}"
SKIP_PUBLISH="${SKIP_PUBLISH:-0}"

step() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# MARK: - Preflight

step "Preflight"
[ -f VERSION ] || die "no VERSION file in $APP_REPO (run this from the app repo's root)"
VERSION="$(tr -d '[:space:]' < VERSION)"
TAG="v$VERSION"
ASSET="$APP_NAME-$VERSION.zip"
CASK_FILE="$TAP_DIR/Casks/$CASK.rb"
REPO_SLUG="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
echo "$APP_NAME $VERSION ($REPO_SLUG), cask $CASK"

[ -z "$(git status --porcelain)" ] || die "app repo has uncommitted changes"
[ -f "$CASK_FILE" ] || die "$CASK_FILE doesn't exist; commit a cask for $CASK to the tap first"

if [ -z "${SIGN_IDENTITY:-}" ]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning | awk '/"Developer ID Application/ { print $2; exit }')"
    [ -n "$SIGN_IDENTITY" ] || die "no Developer ID Application identity in the keychain"
fi
echo "Signing identity: $SIGN_IDENTITY"

xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" > /dev/null 2>&1 \
    || die "notarytool keychain profile '$NOTARY_PROFILE' is missing or invalid; see the setup note at the top of $0"
echo "Notary profile: $NOTARY_PROFILE"

git fetch --quiet --tags origin
CREATED_TAG=0
if git rev-parse -q --verify "refs/tags/$TAG" > /dev/null; then
    echo "Using existing tag $TAG ($(git rev-parse --short "$TAG^{commit}"))"
else
    git tag "$TAG"
    CREATED_TAG=1
    echo "Created tag $TAG at HEAD ($(git rev-parse --short HEAD)); pushed after notarization"
fi

if [ "$SKIP_PUBLISH" != "1" ]; then
    if gh release view "$TAG" --json assets -q '.assets[].name' 2>/dev/null | grep -qx "$ASSET"; then
        die "$REPO_SLUG release $TAG already has $ASSET; bump VERSION for a new release"
    fi
    [ -z "$(git -C "$TAP_DIR" status --porcelain)" ] || die "tap repo has uncommitted changes"
    git -C "$TAP_DIR" pull --quiet --ff-only
fi

BUILD="${BUILD:-$(git rev-list --count "$TAG")}"

# MARK: - Build from the tag

WORK="$(mktemp -d)"
cleanup() {
    git -C "$APP_REPO" worktree remove --force "$WORK/src" > /dev/null 2>&1 || true
    rm -rf "$WORK"
    # Don't leave a local tag behind for a release that never happened.
    if [ "$CREATED_TAG" = "1" ] && [ "${TAG_PUSHED:-0}" != "1" ]; then
        git -C "$APP_REPO" tag -d "$TAG" > /dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

step "Building $TAG (build $BUILD)"
git worktree add --quiet --detach "$WORK/src" "$TAG"
(
    cd "$WORK/src"
    SIGN_IDENTITY="$SIGN_IDENTITY" BUILD="$BUILD" UNIVERSAL=1 bash -c "$BUILD_COMMAND"
)
APP_PATH="$WORK/src/dist/$APP_NAME.app"
[ -d "$APP_PATH" ] || die "build didn't produce dist/$APP_NAME.app"
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | grep -q "Authority=Developer ID Application" \
    || die "$APP_NAME.app isn't signed with Developer ID"
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | grep -q "flags=.*runtime" \
    || die "$APP_NAME.app isn't signed with the hardened runtime"

# MARK: - Notarize and staple

step "Notarizing (usually a few minutes)"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$WORK/notarize.zip"
xcrun notarytool submit "$WORK/notarize.zip" --keychain-profile "$NOTARY_PROFILE" \
    --wait --timeout 30m --output-format json > "$WORK/notary.json" || true
STATUS="$(plutil -extract status raw -o - "$WORK/notary.json" 2>/dev/null || true)"
SUBMISSION_ID="$(plutil -extract id raw -o - "$WORK/notary.json" 2>/dev/null || true)"
echo "Submission ${SUBMISSION_ID:-?}: ${STATUS:-unknown}"
if [ "$STATUS" != "Accepted" ]; then
    cat "$WORK/notary.json" >&2
    if [ -n "$SUBMISSION_ID" ]; then
        xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE" >&2 || true
    fi
    die "notarization failed"
fi

step "Stapling"
# Fetching the ticket right after notarization is flaky; retry.
attempt=1
until xcrun stapler staple "$APP_PATH"; do
    [ "$attempt" -lt 5 ] || die "stapling failed after $attempt attempts"
    echo "Stapling failed (attempt $attempt), retrying in 30s"
    attempt=$((attempt + 1))
    sleep 30
done
xcrun stapler validate "$APP_PATH"
spctl --assess --type execute --verbose=2 "$APP_PATH"

# MARK: - Package

step "Packaging"
mkdir -p "$APP_REPO/dist/release"
ZIP="$APP_REPO/dist/release/$ASSET"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP"
SHA256="$(shasum -a 256 "$ZIP" | awk '{ print $1 }')"
echo "$ZIP"
echo "sha256 $SHA256"

if [ "$SKIP_PUBLISH" = "1" ]; then
    step "SKIP_PUBLISH=1: stopping before tag push, release, and cask bump"
    exit 0
fi

# MARK: - Publish

step "Publishing GitHub Release $TAG"
git push --quiet origin "refs/tags/$TAG"
TAG_PUSHED=1
if gh release view "$TAG" > /dev/null 2>&1; then
    gh release upload "$TAG" "$ZIP" --clobber
else
    gh release create "$TAG" "$ZIP" --title "$APP_NAME $VERSION" --generate-notes --verify-tag
fi

step "Bumping cask $CASK in the tap"
sed -i '' -E \
    -e "s/^(  version \")[^\"]*\"/\1$VERSION\"/" \
    -e "s/^(  sha256 \")[^\"]*\"/\1$SHA256\"/" \
    "$CASK_FILE"
if git -C "$TAP_DIR" diff --quiet; then
    echo "Cask already at $VERSION"
else
    git -C "$TAP_DIR" commit --quiet -am "$CASK $VERSION"
    git -C "$TAP_DIR" push --quiet
fi

step "Released $APP_NAME $VERSION"
echo "https://github.com/$REPO_SLUG/releases/tag/$TAG"
TAP_SLUG="$(cd "$TAP_DIR" && gh repo view --json nameWithOwner -q .nameWithOwner)"
TAP_REPO_NAME="${TAP_SLUG#*/}"
echo "brew update && brew install --cask ${TAP_SLUG%%/*}/${TAP_REPO_NAME#homebrew-}/$CASK"
