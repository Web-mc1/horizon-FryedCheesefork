#!/usr/bin/env bash
# Builds the game client from this fork and puts it over the versions the launcher installed,
# so a nightly that came from upstream still plays as Crispy Launcher (its title, its screens,
# its window icon, the AI Agent page gone).
#
# Usage:
#   ./scripts/rebuild-client.sh          the newest installed version only
#   ./scripts/rebuild-client.sh --all    every installed version
#
# Each version keeps the binary it shipped with as `horizon-client.upstream`, written once, so
# a bad build is undone by copying it back. The build is the same release build the launcher
# runs: cargo build --release -p horizon-client.
set -euo pipefail
cd "$(dirname "$0")/.."

all=0
case "${1:-}" in
    --all) all=1 ;;
    '' | --newest) ;;
    *)
        echo "Unknown option: $1 (expected --all)" >&2
        exit 2
        ;;
esac

data="${HORIZON_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/horizon-launcher}"
versions="$data/versions"
[ -d "$versions" ] || {
    echo "No installed versions in $versions; install one in the launcher first." >&2
    exit 0
}

echo "Building the client (cargo build --release -p horizon-client)…"
cargo build --release -p horizon-client
built="target/release/horizon-client"
[ -x "$built" ] || {
    echo "$built is missing after the build." >&2
    exit 1
}

# Newest first, by when each folder last changed, which is when its version was installed.
if [ "$all" = 1 ]; then
    dirs=$(find "$versions" -mindepth 1 -maxdepth 1 -type d -exec test -e '{}/horizon-client' \; -print |
        xargs -r ls -dt)
else
    dirs=$(find "$versions" -mindepth 1 -maxdepth 1 -type d -exec test -e '{}/horizon-client' \; -print |
        xargs -r ls -dt | head -1)
fi

[ -n "$dirs" ] || {
    echo "No version folder holds a horizon-client." >&2
    exit 0
}

while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    [ -e "$dir/horizon-client.upstream" ] || cp "$dir/horizon-client" "$dir/horizon-client.upstream"
    cp "$built" "$dir/horizon-client"
    echo "Installed the build in $(basename "$dir")"
done <<<"$dirs"

echo "Done. The launcher starts these binaries as they are; a newly installed version needs this again."
