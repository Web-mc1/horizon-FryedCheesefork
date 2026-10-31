# Updating from upstream without losing the Crispy Launcher changes

This fork is Horizon's source with its name, its look and a few of its screens changed. Horizon
ships daily, so "stay current" and "stay ours" have to be reconciled on every update. One
script does it, and a workflow runs that script every night.

## What happens on an update

`scripts/sync-upstream.sh`:

1. **Merges `upstream/main` with `-X ours`.** Every upstream change comes in — bug fixes,
   new features, new crates — except on lines upstream also changed *and* this fork changed:
   there this fork's side stays.
2. **Puts the paths in [`crispy-ui.txt`](../crispy-ui.txt) back exactly as they were.** Whole
   files, because they are a design rather than a patch: the launcher's layout, the mark it
   draws, its palette, the game's settings menu with the AI Agent page removed, the icon set.
   Upstream never wins those.
3. **Takes upstream's version of the files this fork had only rebranded.** `-X ours` settles
   each hunk both sides changed, and the brand touches nearly every string, so an upstream
   refactor can land beside this fork's older copy of the same code — a half-renamed enum, a
   function moved out from under its caller. The test is exact rather than a guess: rebranding
   the merge base's copy of a file has to give this fork's copy byte for byte, which is only
   true when nobody here edited it by hand. Those files take upstream's version whole, and the
   next step puts the name back. A file this fork really changed is never touched this way.
4. **Re-applies the brand**: `scripts/rebrand.sh` (launcher strings, `launcher/lang/`) and
   `scripts/rebrand-game.sh` (the game's own language table and its title), because upstream
   keeps writing "Horizon" into strings it adds.
5. **Commits the result** — one merge commit, nothing pushed from the script.

`.github/workflows/sync-upstream.yml` runs that every day at 04:17 UTC and on demand
(Actions > sync upstream > Run workflow). It then installs the toolchain, regenerates
`docs/launcher-commands.md` (it is generated from the CLI, which upstream changes), builds the
launcher and runs its tests, and only **pushes when the tests pass**. When anything fails it
pushes nothing and comments on the open issue titled *upstream sync failed*.

So the rule is: **main only ever moves forward green.** A sync that needs a decision waits for
one instead of breaking the build.

## Doing it by hand

```sh
./scripts/sync-upstream.sh                  # merge, keep, rebrand, commit (not pushed)
cd launcher && cargo test                   # the same check the workflow runs
git push origin HEAD:main                   # only if it is green
```

Exit 2 means the checkout is dirty (commit or stash first). Exit 3 means git could not settle
the merge on its own — nothing is changed, and the message names `git merge upstream/main` as
the manual route.

## When upstream changes something a protected file calls

A frozen file is still compiled against upstream's everything else, so an upstream change to
an API it uses shows up as a compile error, and the sync fails loudly instead of pushing. The
fix is normal work: take upstream's version of the parts of the frozen file this fork never
touched, keep ours for the rest. Then re-run the script (it is idempotent) and the tests.

## Keeping the game the same after an upstream version installs

The launcher installs Horizon's published builds, so a freshly installed version is upstream's
binary, not this fork's. Rebuild the client from this fork over it:

```sh
./scripts/rebuild-client.sh          # the newest installed version
./scripts/rebuild-client.sh --all    # every installed version
```

Each version folder keeps the binary it shipped with as `horizon-client.upstream` (written
once), so putting it back undoes the rebuild. A newly installed version needs the script again;
the launcher's own self-update is already off, so nothing replaces the launcher itself.
