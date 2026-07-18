#!/usr/bin/env bash

set -euo pipefail

find_potato_script() {
    local dir parent

    dir=$(pwd)

    while true; do
        if [ -x "$dir/potato.sh" ]; then
            printf '%s\n' "$dir/potato.sh"
            return 0
        fi

        parent=$(dirname "$dir")
        if [ "$parent" = "$dir" ]; then
            return 1
        fi
        dir="$parent"
    done
}

POTATO_SCRIPT=$(find_potato_script) || {
    printf 'Could not find potato.sh from %s or any parent directory.\n' "$(pwd)" >&2
    printf 'Run this from inside a simulation-infra checkout or worktree.\n' >&2
    exit 1
}

exec "$POTATO_SCRIPT" "$@"
