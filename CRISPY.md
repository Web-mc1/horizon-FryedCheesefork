# crispylauncher

A rebranded fork of [horizon-rust/horizon](https://github.com/horizon-rust/horizon): the Horizon
launcher, renamed to **crispylauncher**, with the launcher's UI kept under your control so
upstream updates cannot undo it.

Upstream is MIT licensed (`LICENSE`), so a rebrand and redistribution are allowed. The original
copyright notice has to stay: `LICENSE` and `THIRD_PARTY_NOTICES.md` are untouched and must
remain in every copy you ship. "Unofficial, not associated with Mojang or Microsoft" also still
applies — the repo carries no Minecraft code, assets or data, and you need your own Java Edition.

## What was renamed

Everything the player reads:

- the window title, tab labels, page copy, error messages and about text in `launcher/src`
- every language file in `launcher/lang` (keys and values, so lookups stay in step)
- `launcher/README.md` prose

## What was deliberately not renamed

Machine identifiers stay as they are, because the launcher drives upstream builds by those names:

- crate and package names (`horizon-launcher`, `horizon-client`, `horizon-theme`, ...)
- binaries the launcher spawns (`horizon-prepare`, `horizon-ctl`, `horizon-client`)
- env vars (`HORIZON_MINECRAFT_DIR`, `HORIZON_LAUNCHER_NO_SELF_UPDATE`, ...)
- on-disk layout (`~/.horizon`, `ports/<pack>/home/`)
- the mod-registry author check in `launcher/src/browser/horizon.rs`, which compares against
  `["Horizon"]` to recognise upstream packs — that is data, not branding

Renaming those is a much larger change that would cut the launcher off from the game builds it
installs. Do it only if you plan to build and release the game yourself too.

## How updates work now

Two different updates used to exist, and only one of them is left:

- **Game builds** — unchanged. The launcher lists releases from `horizon-rust/horizon`, downloads
  and prepares them, so you keep getting upstream game fixes.
- **Launcher self-update** — disabled in `launcher/src/backend.rs::self_update_allowed()`. Upstream
  ships its own launcher binary as a release asset, and the self-updater replaced this binary with
  it — which is exactly how a custom UI got wiped before. It now returns `false` unless you set
  `CRISPY_LAUNCHER_ALLOW_SELF_UPDATE=1`.

You update the launcher by pulling upstream yourself with `scripts/sync-upstream.sh`.

## Keeping your UI

```bash
git remote add upstream https://github.com/horizon-rust/horizon.git
./scripts/sync-upstream.sh
```

The script fetches upstream, merges it, then:

1. restores your version of every path in `crispy-ui.txt` and stages it
2. re-runs `scripts/rebrand.sh` so "Horizon" strings upstream added are rebranded again
3. commits the merge as one reviewable commit

Add a path to `crispy-ui.txt` when you start customising it, e.g.

```
launcher/src/theme.rs      # colours, radii, spacing
launcher/src/titlebar.rs   # window chrome
launcher/src/home.rs       # the Play page
launcher/assets/           # icons, wordmarks
```

Every path in that file stops receiving upstream fixes, so keep the list tight and prefer editing
files already in it. New screens you add yourself live outside it and merge cleanly anyway.

If the merge hits a real conflict, resolve it and re-run the script; it detects the merge in
progress and carries on.

## Verifying a change

The launcher is its own Cargo workspace (`launcher/`), built with GPUI:

```bash
cd launcher && cargo run --release
```

Upstream's pre-pull-request check, which needs Rust, Python 3.10+ and network for crates:

```bash
python3 tools/pr_ready.py
```

## Still to do on your side

- **The fork itself.** This tree already targets your fork, `Web-mc1/horizon-FryedCheesefork`
  (`origin`), with `upstream` kept on `horizon-rust/horizon` — the names `scripts/sync-upstream.sh`
  expects. Your fork's `main` was identical to upstream when this was built, so the rebrand is a
  fast-forward. Push it with:

  ```bash
  git push origin main
  ```
- **Icons.** `packaging/icons` and `launcher/assets` still hold upstream artwork; drop in your own
  so the rebrand reads as intentional.
- **Releases.** `.github/workflows/launcher.yml` builds and signs launcher releases with upstream's
  setup. It will not produce your builds until you configure signing for your own repo.
- **The website.** `playhorizon.dev` links (docs, privacy, benchmarks) still point at upstream.
  Keep them while you want upstream's documentation, or replace them with your own pages.
