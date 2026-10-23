#!/usr/bin/env bash
#
# Vercel build for the Flutter web app.
#
# Vercel has no Flutter runtime, so the SDK is downloaded once and cached under
# /vercel/.cache (Vercel's writable build cache). The API URL is compiled into
# the bundle, so changing API_BASE_URL requires a redeploy.
#
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.2}"
CACHE_ROOT="${VERCEL_CACHE_DIR:-/vercel/.cache}"
FLUTTER_HOME="${CACHE_ROOT}/flutter-${FLUTTER_VERSION}"

if [ ! -x "${FLUTTER_HOME}/bin/flutter" ]; then
  echo "Downloading Flutter ${FLUTTER_VERSION} to ${FLUTTER_HOME}"
  rm -rf "${FLUTTER_HOME}"
  mkdir -p "$(dirname "${FLUTTER_HOME}")"
  git clone --depth 1 --branch "${FLUTTER_VERSION}" \
    https://github.com/flutter/flutter.git "${FLUTTER_HOME}"
fi

export PATH="${FLUTTER_HOME}/bin:${PATH}"
export PUB_CACHE="${CACHE_ROOT}/pub-cache"

: "${API_BASE_URL:?API_BASE_URL is not set. Add it in the Vercel project environment (e.g. https://api.example.com/api/v1).}"

flutter --version
flutter config --no-analytics >/dev/null
flutter pub get
flutter build web --release --dart-define=API_BASE_URL="${API_BASE_URL}"

echo "Built build/web"
