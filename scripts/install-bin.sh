#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-${ROOT}/target}"
export GROK_DISABLE_AUTOUPDATER=1

src="${CARGO_TARGET_DIR}/release/xai-grok-pager"
dst="${ROOT}/bin/grok-omarchy"

if [[ ! -f "${src}" ]]; then
  echo "error: missing ${src} (run scripts/build.sh first)" >&2
  exit 1
fi

mkdir -p "${ROOT}/bin"
install -m755 "${src}" "${dst}"
"${dst}" --version
