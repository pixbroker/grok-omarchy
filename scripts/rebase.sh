#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT}/grok-build"

if [[ ! -d "${BUILD_DIR}" ]]; then
  echo "error: grok-build missing at ${BUILD_DIR}" >&2
  exit 1
fi

cd "${BUILD_DIR}"

if ! git remote get-url upstream >/dev/null 2>&1; then
  git remote add upstream https://github.com/xai-org/grok-build
fi

git fetch upstream main

if ! git rebase upstream/main omarchy; then
  echo "error: rebase of omarchy onto upstream/main failed" >&2
  echo "conflicting files:" >&2
  conflicts="$(git diff --name-only --diff-filter=U || true)"
  if [[ -n "${conflicts}" ]]; then
    printf '%s\n' "${conflicts}" >&2
  else
    echo "(none listed as unmerged; git status:)" >&2
    git status --short >&2
  fi
  echo "Resolve conflicts, then git rebase --continue (or git rebase --abort). Do not --force." >&2
  exit 1
fi

"${ROOT}/scripts/build.sh"
"${ROOT}/scripts/install-bin.sh"
"${ROOT}/scripts/export-patches.sh"
