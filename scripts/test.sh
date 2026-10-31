#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
scratch_path="${TMPDIR:-/tmp}/woa-swift-tests-${UID}"

cd "$repo_root"
exec swift test --scratch-path "$scratch_path" --jobs "${SWIFT_TEST_JOBS:-2}" "$@"
