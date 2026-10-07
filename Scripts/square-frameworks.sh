#!/usr/bin/env bash
# Prepares the embedded Square In-App Payments SDK for App Store distribution.
#
# Square ships CorePaymentCard nested inside SquareInAppPaymentsSDK.framework and marks the
# framework's Info.plist as an application (CFBundlePackageType APPL). App Store Connect rejects
# both: altool looks for an app record for com.squareup.square-in-app-payments-sdk. This fixes
# the package type, then runs Square's own setup script, which moves the nested frameworks up to
# the app's Frameworks folder and re-signs them.
set -euo pipefail

sdk="$BUILT_PRODUCTS_DIR/$FRAMEWORKS_FOLDER_PATH/SquareInAppPaymentsSDK.framework"
[[ -d "$sdk" ]] || exit 0

/usr/libexec/PlistBuddy -c "Set :CFBundlePackageType FMWK" "$sdk/Info.plist"

# Square's setup re-signs what it moves, which fails with no identity when signing is off (CI's
# simulator builds pass CODE_SIGNING_ALLOWED=NO). Unsigned builds never reach the App Store.
[[ "${CODE_SIGNING_ALLOWED:-YES}" == "NO" ]] && exit 0
[[ -x "$sdk/setup" ]] && "$sdk/setup"
