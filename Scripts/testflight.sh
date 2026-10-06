#!/usr/bin/env bash
# Archives the Release build, exports it for App Store Connect and uploads it to TestFlight.
#
#   Scripts/testflight.sh                 # archive, export and upload
#   Scripts/testflight.sh --export-only   # stop after exporting build/testflight/export/HotMess.ipa
#
# The build number defaults to the UTC time (yyyymmddHHMM), so every upload is newer than the
# last; set BUILD_NUMBER to choose one. Signing is automatic with team DWVXMLB45Y, so Xcode needs
# to be signed in to an account on that team, with an Apple Distribution certificate in the keychain.
#
# The upload uses an App Store Connect API key (Users and Access -> Integrations -> Team Keys,
# role App Manager or Developer). It's the same key garage-rag uploads with: the login keychain
# item with service me.rickmark.garage-rag.asc-api-key, whose account is the key ID, comment the
# issuer ID and password the base64 of AuthKey_<KEY ID>.p8. ASC_KEY_ID, ASC_ISSUER_ID and
# ASC_KEY_PATH (the .p8 file) override it.
set -euo pipefail

KEYCHAIN_SERVICE="me.rickmark.garage-rag.asc-api-key"
TEAM_ID="DWVXMLB45Y"

die() {
    echo "testflight: $*" >&2
    exit 1
}

mode="upload"
case "${1:-}" in
    "") ;;
    --export-only) mode="export" ;;
    *) die "unknown argument $1" ;;
esac

root="$(cd "$(dirname "$0")/.." && pwd -P)"
out="$root/build/testflight"
build_number="${BUILD_NUMBER:-$(date -u +%Y%m%d%H%M)}"

work="$(mktemp -d "${TMPDIR:-/tmp}/hotmess-testflight.XXXXXX")"
trap 'rm -rf "$work"' EXIT

# Credentials come before the slow archive, so a missing key fails at once.
if [[ "$mode" == "upload" ]]; then
    mkdir -m 700 "$work/private_keys"
    key_id="${ASC_KEY_ID:-}" issuer_id="${ASC_ISSUER_ID:-}"
    if [[ -n "${ASC_KEY_PATH:-}" ]]; then
        [[ -n "$key_id" && -n "$issuer_id" ]] || die "ASC_KEY_PATH needs ASC_KEY_ID and ASC_ISSUER_ID"
        cp "$ASC_KEY_PATH" "$work/private_keys/AuthKey_$key_id.p8"
    else
        attributes="$(security find-generic-password -s "$KEYCHAIN_SERVICE" 2>/dev/null)" ||
            die "no App Store Connect API key in the keychain; store it once with:
  security add-generic-password -U -s $KEYCHAIN_SERVICE -a <KEY ID> -j <ISSUER ID> -w \"\$(base64 < AuthKey_<KEY ID>.p8)\""
        [[ -n "$key_id" ]] || key_id="$(sed -n 's/^ *"acct"<blob>="\(.*\)"$/\1/p' <<<"$attributes")"
        [[ -n "$issuer_id" ]] || issuer_id="$(sed -n 's/^ *"icmt"<blob>="\(.*\)"$/\1/p' <<<"$attributes")"
        [[ -n "$key_id" && -n "$issuer_id" ]] ||
            die "the keychain item needs the key ID as its account and the issuer ID as its comment"
        (umask 077 && security find-generic-password -s "$KEYCHAIN_SERVICE" -w | base64 -D \
            > "$work/private_keys/AuthKey_$key_id.p8") || die "could not read the API key from the keychain"
    fi
fi

rm -rf "$out"
mkdir -p "$out"

echo "==> Archiving HotMess Release, build $build_number"
xcodebuild archive \
    -project "$root/HotMess.xcodeproj" \
    -scheme "HotMess Release" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$out/HotMess.xcarchive" \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CURRENT_PROJECT_VERSION="$build_number"

echo "==> Exporting for App Store Connect"
xcodebuild -exportArchive \
    -archivePath "$out/HotMess.xcarchive" \
    -exportOptionsPlist "$root/Configurations/ExportOptions-AppStore.plist" \
    -exportPath "$out/export" \
    -allowProvisioningUpdates

ipa="$out/export/HotMess.ipa"
[[ -f "$ipa" ]] || die "the export didn't produce $ipa"
[[ "$mode" == "export" ]] && { echo "==> Exported $ipa"; exit 0; }

# altool looks for AuthKey_<KEY ID>.p8 in ./private_keys among other places.
cd "$work"
echo "==> Validating"
xcrun altool --validate-app -f "$ipa" -t ios --apiKey "$key_id" --apiIssuer "$issuer_id"
echo "==> Uploading to TestFlight"
xcrun altool --upload-app -f "$ipa" -t ios --apiKey "$key_id" --apiIssuer "$issuer_id"
echo "==> Uploaded build $build_number. It shows in TestFlight once App Store Connect has processed it."
