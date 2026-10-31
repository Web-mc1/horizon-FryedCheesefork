#!/usr/bin/env bash
# Applies the brand to the launcher's user-facing text. Idempotent; run after every
# upstream merge, because upstream keeps writing "Horizon" into new strings.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
perl scripts/rebrand.pl $(git ls-files 'launcher/src/*.rs' 'launcher/lang/*.json' 'launcher/README.md')
