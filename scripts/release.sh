#!/usr/bin/env bash
# Archive, export (Developer ID), notarize, staple, build the DMG and Sparkle-sign it.
# Runs on the dev machine: uses the Developer ID cert and the notarytool keychain profile.
#
#   scripts/release.sh                    release the version already in the Xcode project
#   scripts/release.sh --version 1.31.0   bump MARKETING_VERSION / CURRENT_PROJECT_VERSION first
#   scripts/release.sh --dry-run          archive + export + DMG only (no notarize, no Sparkle sign)
#   scripts/release.sh --out DIR          build somewhere other than build/v<version>
#
# Output: build/v<version>/{Caffee.app, Caffee-v<version>.dmg, release-info.json, logs}
set -euo pipefail

PROFILE="${NOTARY_PROFILE:-icetea-notary}"
SCHEME="Caffee"
PBXPROJ_REL="Caffee.xcodeproj/project.pbxproj"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

NEW_VERSION=""
OUT_OVERRIDE=""
DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) NEW_VERSION="${2:?--version needs X.Y.Z}"; shift 2 ;;
    --profile) PROFILE="${2:?--profile needs a name}"; shift 2 ;;
    --out) OUT_OVERRIDE="${2:?--out needs a directory}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

step() { printf '\n==> %s\n' "$*"; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- version
current_version() { grep -m1 -oE 'MARKETING_VERSION = [0-9]+\.[0-9]+\.[0-9]+' "$PBXPROJ_REL" | awk '{print $3}'; }
current_build()   { grep -m1 -oE 'CURRENT_PROJECT_VERSION = [0-9]{5}' "$PBXPROJ_REL" | awk '{print $3}'; }

OLD_VERSION="$(current_version)"; OLD_BUILD="$(current_build)"
[[ -n "$OLD_VERSION" && -n "$OLD_BUILD" ]] || die "cannot read version from $PBXPROJ_REL"

if [[ -n "$NEW_VERSION" && "$NEW_VERSION" != "$OLD_VERSION" ]]; then
  [[ "$NEW_VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || die "version must be X.Y.Z"
  NEW_BUILD=$(( BASH_REMATCH[1] * 10000 + BASH_REMATCH[2] * 100 + BASH_REMATCH[3] ))
  step "Bump version $OLD_VERSION ($OLD_BUILD) -> $NEW_VERSION ($NEW_BUILD)"
  # Match the exact old values so the test targets (version 1.0) stay untouched.
  sed -i '' \
    -e "s/MARKETING_VERSION = $OLD_VERSION;/MARKETING_VERSION = $NEW_VERSION;/" \
    -e "s/CURRENT_PROJECT_VERSION = $OLD_BUILD;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/" \
    "$PBXPROJ_REL"
fi
VERSION="$(current_version)"; BUILD="$(current_build)"
TAG="v$VERSION"

OUT="${OUT_OVERRIDE:-$ROOT/build/$TAG}"
ARCHIVE="$OUT/Caffee.xcarchive"
EXPORT="$OUT/export"
APP="$OUT/Caffee.app"
DMG="$OUT/Caffee-$TAG.dmg"
LOG="$OUT/release-build.log"

# ---------------------------------------------------------------- preflight
step "Preflight ($TAG, build $BUILD$([[ $DRY_RUN == 1 ]] && echo ', dry run'))"
SIGN_UPDATE="$(command -v sign_update || true)"; [[ -n "$SIGN_UPDATE" ]] || SIGN_UPDATE="$HOME/Code/tools/sign_update"
for tool in xcodebuild xcrun ditto hdiutil create-dmg; do
  command -v "$tool" >/dev/null || die "missing tool: $tool"
done
[[ -x "$SIGN_UPDATE" ]] || die "sign_update not found (see RELEASE.md step 0)"
IDENTITY="$(security find-identity -v -p codesigning | grep 'Developer ID Application' | head -1 | sed -E 's/.*"(.*)"/\1/')"
[[ -n "$IDENTITY" ]] || die "no 'Developer ID Application' identity in the keychain"
echo "signing identity: $IDENTITY"
if [[ $DRY_RUN == 0 ]]; then
  xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1 \
    || die "notarytool profile '$PROFILE' not usable (xcrun notarytool store-credentials \"$PROFILE\" ...)"
  echo "notary profile:   $PROFILE"
fi
if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
  echo "warning: working tree has uncommitted changes (they will be part of this build)"
fi

# Never wipe a previous release folder (it holds the shipped DMG and notary logs).
if [[ -n "$(ls -A "$OUT" 2>/dev/null)" ]]; then
  die "$OUT already exists and is not empty — move it away or pass --out DIR"
fi
mkdir -p "$OUT"
: > "$LOG"

notarize() { # <file> <label>  — submit, wait, fail with the Apple log when not Accepted
  local file="$1" label="$2" json="$OUT/notary-$2.json"
  step "Notarize $label (can take a few minutes)"
  xcrun notarytool submit "$file" --keychain-profile "$PROFILE" --wait --output-format json > "$json"
  local status id
  status="$(plutil -extract status raw -o - "$json")"; id="$(plutil -extract id raw -o - "$json")"
  if [[ "$status" != "Accepted" ]]; then
    xcrun notarytool log "$id" --keychain-profile "$PROFILE" "$OUT/notary-$label-log.json" || true
    die "notarization of $label: $status — see $OUT/notary-$label-log.json"
  fi
  echo "accepted ($id)"
}

# ---------------------------------------------------------------- archive + export
step "Archive (Release)"
xcodebuild archive -scheme "$SCHEME" -configuration Release \
  -archivePath "$ARCHIVE" -derivedDataPath "$OUT/DerivedData" >> "$LOG" 2>&1 \
  || { tail -40 "$LOG" >&2; die "archive failed (full log: $LOG)"; }

step "Export (Developer ID)"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT" \
  -exportOptionsPlist "$ROOT/scripts/ExportOptions.plist" >> "$LOG" 2>&1 \
  || { tail -40 "$LOG" >&2; die "export failed (full log: $LOG)"; }
cp -R "$EXPORT/Caffee.app" "$APP"

step "Verify code signature"
codesign --verify --deep --strict --verbose=2 "$APP" 2>&1 | tail -3
codesign -dv --verbose=4 "$APP" 2>&1 | grep -E 'Authority=Developer ID Application|flags=.*runtime|TeamIdentifier' \
  || die "app is not signed with Developer ID + hardened runtime"
APP_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$APP/Contents/Info.plist")"
[[ "$APP_VERSION" == "$VERSION" ]] || die "built app is $APP_VERSION, expected $VERSION"

# ---------------------------------------------------------------- notarize app
if [[ $DRY_RUN == 0 ]]; then
  ditto -c -k --keepParent "$APP" "$OUT/Caffee-notarization.zip"
  notarize "$OUT/Caffee-notarization.zip" app
  step "Staple app"
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  spctl -a -vv "$APP" 2>&1 | head -3
fi

# ---------------------------------------------------------------- dmg
step "Create DMG"
STAGE="$OUT/dmg-stage"; mkdir -p "$STAGE"
create-dmg --overwrite --identity="$IDENTITY" "$APP" "$STAGE" >> "$LOG" 2>&1 \
  || { tail -20 "$LOG" >&2; die "create-dmg failed"; }
GENERATED="$(find "$STAGE" -maxdepth 1 -name '*.dmg' | head -1)"
[[ -n "$GENERATED" ]] || die "create-dmg produced no .dmg"
mv "$GENERATED" "$DMG"; rm -rf "$STAGE"
codesign --verify --verbose=2 "$DMG" 2>&1 | tail -2

if [[ $DRY_RUN == 1 ]]; then
  step "Dry run done (not notarized, not Sparkle-signed)"
  echo "app: $APP"; echo "dmg: $DMG"
  exit 0
fi

notarize "$DMG" dmg
step "Staple DMG"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl -a -t open --context context:primary-signature -vv "$DMG" 2>&1 | head -3

# ---------------------------------------------------------------- sparkle + checksums
# Must run last: stapling changes the DMG bytes, so the signature has to cover the final file.
step "Sparkle signature"
SIG_LINE="$("$SIGN_UPDATE" "$DMG")"
ED_SIG="$(sed -E 's/.*sparkle:edSignature="([^"]+)".*/\1/' <<<"$SIG_LINE")"
LENGTH="$(stat -f%z "$DMG")"
SHA256="$(shasum -a 256 "$DMG" | awk '{print $1}')"
PUB_DATE="$(LC_ALL=C date '+%a, %d %b %Y %H:%M:%S %z')"
[[ -n "$ED_SIG" && "$ED_SIG" != "$SIG_LINE" ]] || die "could not parse sign_update output: $SIG_LINE"
echo "$SIG_LINE" > "$OUT/sparkle-signature.txt"

PREV_TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"
cat > "$OUT/release-info.json" <<JSON
{
  "version": "$VERSION",
  "tag": "$TAG",
  "build": $BUILD,
  "previous_tag": "${PREV_TAG}",
  "dmg": "$DMG",
  "dmg_name": "Caffee-$TAG.dmg",
  "download_url": "https://github.com/khanhicetea/Caffee/releases/download/$TAG/Caffee-$TAG.dmg",
  "sparkle_ed_signature": "$ED_SIG",
  "length": $LENGTH,
  "sha256": "$SHA256",
  "pub_date": "$PUB_DATE"
}
JSON

step "Release ready: $TAG"
cat "$OUT/release-info.json"
echo
echo "Next: update web/{appcast.xml,index.html,download.html}, upload the DMG to the GitHub release $TAG, deploy web/."
