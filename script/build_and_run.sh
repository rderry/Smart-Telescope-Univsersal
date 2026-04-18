#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Smart Scope Observation Planner"
BUNDLE_ID="com.bigskyastro.SmartScopeObservationPlanner"
PROJECT_NAME="AstronomyObservationPlanning.xcodeproj"
SCHEME_NAME="AstronomyObservationPlanning"
DERIVED_DATA=".xcodeDerivedSmartScope"
DEBUG_CONFIGURATION="Debug"
RELEASE_CONFIGURATION="Release"
INTEL_ARCHS="x86_64"
UNIVERSAL_ARCHS="arm64 x86_64"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="$ROOT_DIR/$DERIVED_DATA"
APP_BINARY_PATTERN="/$APP_NAME.app/Contents/MacOS/$APP_NAME"

app_bundle_for_configuration() {
  local configuration="$1"
  printf "%s/Build/Products/%s/%s.app" "$DERIVED_DATA_PATH" "$configuration" "$APP_NAME"
}

app_binary_for_configuration() {
  local configuration="$1"
  printf "%s/Contents/MacOS/%s" "$(app_bundle_for_configuration "$configuration")" "$APP_NAME"
}

stop_running_app() {
  /usr/bin/osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
  /usr/bin/osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true

  for _ in {1..20}; do
    if /usr/bin/pgrep -x "$APP_NAME" >/dev/null 2>&1 || /usr/bin/pgrep -f "$APP_BINARY_PATTERN" >/dev/null 2>&1; then
      sleep 0.2
    else
      return 0
    fi
  done

  /usr/bin/pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  /usr/bin/pkill -f "$APP_BINARY_PATTERN" >/dev/null 2>&1 || true
}

build_app() {
  local configuration="$1"
  shift

  /usr/bin/xcodebuild \
    -project "$ROOT_DIR/$PROJECT_NAME" \
    -scheme "$SCHEME_NAME" \
    -configuration "$configuration" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -destination "platform=macOS" \
    CODE_SIGNING_ALLOWED=NO \
    ONLY_ACTIVE_ARCH=NO \
    "$@" \
    build
}

open_app() {
  local configuration="${1:-$DEBUG_CONFIGURATION}"
  /usr/bin/open "$(app_bundle_for_configuration "$configuration")"
  /usr/bin/osascript -e "tell application \"$APP_NAME\" to activate" >/dev/null 2>&1 || true
}

architectures_for_configuration() {
  local configuration="$1"
  /usr/bin/lipo -archs "$(app_binary_for_configuration "$configuration")"
}

print_architectures() {
  local configuration="$1"
  local binary
  local architectures

  binary="$(app_binary_for_configuration "$configuration")"
  architectures="$(architectures_for_configuration "$configuration")"
  printf "%s: %s\n" "$binary" "$architectures"
}

require_architecture() {
  local configuration="$1"
  local required_architecture="$2"
  local architectures

  architectures="$(architectures_for_configuration "$configuration")"
  case " $architectures " in
    *" $required_architecture "*) ;;
    *)
      printf "Expected %s binary to include %s, got: %s\n" "$configuration" "$required_architecture" "$architectures" >&2
      return 1
      ;;
  esac

  printf "Verified %s includes %s\n" "$configuration" "$required_architecture"
}

require_universal() {
  local configuration="$1"
  require_architecture "$configuration" arm64
  require_architecture "$configuration" x86_64
}

case "$MODE" in
  run)
    stop_running_app
    build_app "$DEBUG_CONFIGURATION"
    stop_running_app
    open_app "$DEBUG_CONFIGURATION"
    ;;
  --debug|debug)
    stop_running_app
    build_app "$DEBUG_CONFIGURATION"
    /usr/bin/lldb -- "$(app_binary_for_configuration "$DEBUG_CONFIGURATION")"
    ;;
  --logs|logs)
    stop_running_app
    build_app "$DEBUG_CONFIGURATION"
    stop_running_app
    open_app "$DEBUG_CONFIGURATION"
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    stop_running_app
    build_app "$DEBUG_CONFIGURATION"
    stop_running_app
    open_app "$DEBUG_CONFIGURATION"
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    stop_running_app
    build_app "$DEBUG_CONFIGURATION"
    stop_running_app
    open_app "$DEBUG_CONFIGURATION"
    sleep 1
    /usr/bin/pgrep -x "$APP_NAME" >/dev/null || /usr/bin/pgrep -f "$APP_BINARY_PATTERN" >/dev/null
    ;;
  --build-intel|build-intel|--verify-intel|verify-intel)
    build_app "$RELEASE_CONFIGURATION" "ARCHS=$INTEL_ARCHS"
    print_architectures "$RELEASE_CONFIGURATION"
    require_architecture "$RELEASE_CONFIGURATION" x86_64
    ;;
  --build-universal|build-universal|--verify-universal|verify-universal)
    build_app "$RELEASE_CONFIGURATION" "ARCHS=$UNIVERSAL_ARCHS"
    print_architectures "$RELEASE_CONFIGURATION"
    require_universal "$RELEASE_CONFIGURATION"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--verify-intel|--verify-universal]" >&2
    exit 2
    ;;
esac
