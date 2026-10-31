#!/usr/bin/env bash
# Rebrands what the game itself shows: its lang table and the version label.
#
# The game's menus are not string literals in Rust — they are keys in
# crates/horizon-client/assets/horizon/lang/*.json, whose values are what the player reads.
# Keys are lowercase and dotted (`horizon.pages.settings`), so the capitalised brand only ever
# appears in a value and a plain replacement is safe for the file.
#
# Log lines and diagnostic messages keep the old spelling on purpose: they name the upstream
# project in crash reports, and several are compared verbatim by tests.
#
# Idempotent: running it twice changes nothing the second time.
set -euo pipefail
cd "$(dirname "$0")/.."

perl -pi -e 's/\bHorizon\b/Crispy Launcher/g' \
    crates/horizon-client/assets/horizon/lang/*.json

# The version label drawn in the title screen's corner.
perl -pi -e 's/"Horizon \{\} \(Rust\)"/"Crispy Launcher {} (Rust)"/' \
    crates/horizon-client/src/title.rs

echo "game strings rebranded"
