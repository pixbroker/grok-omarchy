#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT}/grok-build"
PATCH_DIR="${ROOT}/patches"

if [[ ! -d "${BUILD_DIR}" ]]; then
  echo "error: grok-build missing at ${BUILD_DIR}" >&2
  exit 1
fi

mkdir -p "${PATCH_DIR}"
rm -f "${PATCH_DIR}"/*.patch

cd "${BUILD_DIR}"
git format-patch 72a61251..omarchy -o "${PATCH_DIR}"
