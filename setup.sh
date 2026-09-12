#!/usr/bin/env bash
# Friendly repository-root entry point.
set -Eeuo pipefail
TASK_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec bash "$TASK_DIR/scripts/setup_linux.sh" "$@"
