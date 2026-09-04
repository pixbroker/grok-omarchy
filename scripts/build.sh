#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT}/grok-build"

if [[ ! -d "${BUILD_DIR}" ]]; then
  echo "error: grok-build missing at ${BUILD_DIR}" >&2
  exit 1
fi

if ! command -v dotslash >/dev/null 2>&1 && ! command -v protoc >/dev/null 2>&1; then
  echo "error: need dotslash or protoc on PATH" >&2
  exit 1
fi

# This machine rewrites https://github.com/ → git@github.com: in global git
# config, which breaks cargo's libgit2 fetch of our-forks/async-openai. Do not
# change git config; isolate cargo's git from it and use the git CLI instead.
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null
export CARGO_NET_GIT_FETCH_WITH_CLI=true
export CARGO_TARGET_DIR="${ROOT}/target"
export GROK_DISABLE_AUTOUPDATER=1

cd "${BUILD_DIR}"

UPSTREAM_VERSION=$(sed -nE 's/^# ([0-9]+\.[0-9]+\.[0-9]+) .*/\1/p' crates/codegen/xai-grok-shell/CHANGELOG.md | head -1)
if [[ -z "${UPSTREAM_VERSION}" ]]; then
  echo "error: could not parse UPSTREAM_VERSION from crates/codegen/xai-grok-shell/CHANGELOG.md" >&2
  exit 1
fi

GROK_VERSION="${UPSTREAM_VERSION}-omarchy.$(git rev-parse --short=8 HEAD)"
echo "GROK_VERSION=${GROK_VERSION}"

GROK_VERSION="$GROK_VERSION" cargo build -p xai-grok-pager-bin --release
