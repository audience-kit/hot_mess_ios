#!/bin/sh
# Xcode Cloud runs this before each xcodebuild. For the test actions it points the UI tests at the server
# for the branch being built: main talks to production, every other branch (next, feature branches) to the
# next API. A pull request build uses the branch it targets. The tests read it as HOTMESS_TEST_API_URL
# (see XCUIApplication.runnerAPI); without it, as on a local run, the sign-in tests skip.
set -eu

case "${CI_XCODEBUILD_ACTION:-}" in
build-for-testing | test-without-building) ;;
*) exit 0 ;;
esac

branch="${CI_BRANCH:-${CI_PULL_REQUEST_TARGET_BRANCH:-}}"
case "$branch" in
main) api="https://api.audiencekit.com" ;;
*) api="https://api.next.audiencekit.com" ;;
esac

scheme="$CI_PRIMARY_REPOSITORY_PATH/HotMess.xcodeproj/xcshareddata/xcschemes/$CI_XCODE_SCHEME.xcscheme"
if ! grep -q "HOTMESS_TEST_API_URL" "$scheme"; then
    HOTMESS_TEST_API_URL="$api" perl -0pi -e '
        s{(<TestAction\b[^>]*?)shouldUseLaunchSchemeArgsEnv = "YES">}{$1shouldUseLaunchSchemeArgsEnv = "NO">
      <EnvironmentVariables>
         <EnvironmentVariable
            key = "HOTMESS_TEST_API_URL"
            value = "$ENV{HOTMESS_TEST_API_URL}"
            isEnabled = "YES">
         </EnvironmentVariable>
      </EnvironmentVariables>}
    ' "$scheme"
fi
grep -q "value = \"$api\"" "$scheme" || { echo "error: couldn't set HOTMESS_TEST_API_URL in $scheme" >&2; exit 1; }
echo "UI tests on branch '$branch' use $api"
