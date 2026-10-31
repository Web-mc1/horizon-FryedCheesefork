#!/usr/bin/env bash
# Merge upstream horizon without letting it overwrite the crispy UI.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-upstream}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-main}"

git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1 ||
    git remote add "$UPSTREAM_REMOTE" https://github.com/horizon-rust/horizon.git
git fetch "$UPSTREAM_REMOTE" "$UPSTREAM_BRANCH"

if ! git rev-parse -q --verify MERGE_HEAD >/dev/null; then
    if git merge-base --is-ancestor "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH" HEAD; then
        echo "Already up to date with $UPSTREAM_REMOTE/$UPSTREAM_BRANCH."
        exit 0
    fi
    git merge --no-ff --no-commit "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH" || true
fi

kept=0
while IFS= read -r path; do
    case "$path" in ''|'#'*) continue ;; esac
    [ -e "$path" ] || continue
    if git checkout HEAD -- "$path" 2>/dev/null; then
        git add -A -- "$path"
        kept=$((kept + 1))
    fi
done < crispy-ui.txt
echo "Kept $kept protected UI path(s) from your branch."

./scripts/rebrand.sh

git add -A
if git diff --cached --quiet; then
    echo "Nothing to commit."
    exit 0
fi
git commit -m "Merge $UPSTREAM_REMOTE/$UPSTREAM_BRANCH, keeping the crispy UI"
