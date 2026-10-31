#!/usr/bin/env bash
# Brings horizon-rust/horizon's newest work into this fork and keeps everything that makes it
# Crispy Launcher.
#
# How the two are reconciled, in order:
#
#   1. `git merge -X ours` — every upstream change comes in, except where upstream and this
#      fork changed the same lines: there this fork's side stays.
#   2. The paths in crispy-ui.txt are put back exactly as they were, whole files: the look,
#      the layout, the screens we replaced. Upstream never wins those.
#   3. scripts/rebrand.sh and scripts/rebrand-game.sh run again, because upstream keeps
#      writing "Horizon" into new strings and new language entries.
#
# The result is committed but not pushed: the workflow (.github/workflows/sync-upstream.yml)
# builds and tests it first, and only then pushes. Run `cargo test --manifest-path
# launcher/Cargo.toml` yourself before pushing when you run this by hand.
#
# Exits 0 when there was nothing to do or the merge committed, 2 for a dirty checkout, and 3
# when the merge cannot be settled automatically (nothing is changed in that case).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-upstream}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-main}"
UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/horizon-rust/horizon.git}"

say() { printf '%s\n' "$*" >&2; }

# GitHub Actions reads this to know whether there is a commit to build and push.
merged() {
    [ -z "${GITHUB_OUTPUT:-}" ] || printf 'merged=%s\n' "$1" >>"$GITHUB_OUTPUT"
}

if ! git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
    say "Adding $UPSTREAM_URL as $UPSTREAM_REMOTE."
    git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
fi

git fetch --quiet "$UPSTREAM_REMOTE" "$UPSTREAM_BRANCH"
target="$UPSTREAM_REMOTE/$UPSTREAM_BRANCH"

if git merge-base --is-ancestor "$target" HEAD; then
    say "Already up to date with $target."
    merged false
    exit 0
fi

if [ -n "$(git status --porcelain)" ]; then
    say "This checkout has uncommitted changes; commit or stash them first, so the merge is one commit."
    exit 2
fi

start=$(git rev-parse HEAD)
# Where this fork last stood with upstream: a file whose only change since then was the brand
# is one nobody here edited.
base=$(git merge-base "$start" "$target")
say "Merging $target ($(git rev-list --count "HEAD..$target") upstream commits)."

# --no-commit keeps HEAD at $start while the merge sits in the index, so the protected paths
# can be taken from this fork's own commit below and the whole thing lands as one commit.
if ! git merge --no-commit --no-ff -X ours "$target"; then
    # -X ours settles every changed line. What it cannot settle is a file one side deleted and
    # the other edited, and deleting a screen is one of this fork's changes: a file we deleted
    # stays deleted, however much upstream edited it afterwards.
    left=0
    while IFS= read -r path; do
        [ -n "$path" ] || continue
        if ! git cat-file -e "$start:$path" 2>/dev/null && git cat-file -e "$target:$path" 2>/dev/null; then
            git rm --quiet -f --ignore-unmatch -- "$path"
            say "Kept deleted: $path"
        else
            say "Could not settle: $path"
            left=$((left + 1))
        fi
    done <<<"$(git diff --name-only --diff-filter=U)"

    if [ "$left" -gt 0 ]; then
        git merge --abort 2>/dev/null || true
        say "Upstream and this fork disagree on $left path(s) this script cannot call. Nothing was"
        say "changed; merge it by hand with: git merge $target"
        merged false
        exit 3
    fi
fi

kept=0
while IFS= read -r path; do
    case "$path" in ''|'#'*) continue ;; esac
    [ -e "$path" ] || continue
    git checkout "$start" -- "$path"
    kept=$((kept + 1))
done < crispy-ui.txt
say "Kept $kept protected path(s) exactly as they were."

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
temp=0

# Is $1 one of the paths crisp-ui.txt protects?
protected() {
    local path=$1 p
    while IFS= read -r p; do
        case "$p" in ''|'#'*) continue ;; esac
        case "$path" in "$p" | "$p"/*) return 0 ;; esac
    done < crispy-ui.txt
    return 1
}

# Did this fork only apply the brand to $1 since the merge base? Rebranding the base's copy has
# to give this fork's copy byte for byte; anything else means a person edited it too.
only_rebranded() {
    local path=$1 copy theirs
    git cat-file -e "$base:$path" 2>/dev/null || return 1
    temp=$((temp + 1))
    copy="$work/$temp.${path##*.}"
    theirs="$work/o$temp.${path##*.}"
    git show "$base:$path" >"$copy"
    git show "$start:$path" >"$theirs"
    perl scripts/rebrand.pl "$copy" >/dev/null 2>&1 || return 1
    cmp -s "$copy" "$theirs"
}

# `-X ours` settles each hunk both sides changed, and the brand changes nearly every string, so
# upstream's restructuring lands beside this fork's older copy of the same code: a half-renamed
# enum, a function moved out from under its caller. Neither side compiles that. Such a file has
# nothing of ours to lose, so upstream's version replaces it whole and the rebrand below puts
# the name back — which is what keeps a nightly that reshuffles the launcher from needing work
# by hand every morning.
taken=0
while IFS= read -r path; do
    [ -n "$path" ] || continue
    git cat-file -e "$target:$path" 2>/dev/null || continue
    [ -f "$path" ] || continue
    protected "$path" && continue
    only_rebranded "$path" || continue
    git checkout "$target" -- "$path"
    taken=$((taken + 1))
done <<<"$(git diff --name-only "$base" "$target" -- launcher/src)"
say "Took upstream's version of $taken file(s) this fork had only rebranded."

./scripts/rebrand.sh
./scripts/rebrand-game.sh

git add -A
if git diff --cached --quiet; then
    # Everything upstream changed was a protected path (or the brand alone), so there is no
    # merge to record: put the checkout back exactly as it was rather than leave it mid-merge.
    git merge --abort 2>/dev/null || git reset --hard --quiet "$start"
    say "Upstream had nothing this fork did not already have; the checkout is unchanged."
    merged false
    exit 0
fi

git commit --quiet -m "Merge $target, keeping the Crispy Launcher changes" -m \
"This is scripts/sync-upstream.sh: upstream's changes came in, the lines it changed that this
fork also changed stayed ours, the paths in crispy-ui.txt were kept whole, and the brand was
re-applied to the strings upstream added.

Build and test before pushing: cargo test --manifest-path launcher/Cargo.toml"

merged true
say "Merged into $(git rev-parse --short HEAD). Next:"
say "  cargo test --manifest-path launcher/Cargo.toml"
say "  git push origin HEAD:main"
