# Presentation capture

`./dev.sh capture` starts an isolated OpenMW session, loads the configured
content profile and save, renders the development-only presentation deck, and
publishes the resulting images under `media/`.

The capture overlay lives in `dev-content/`, outside the production mod source.
It is copied into the local development data directory only for the duration of
a capture and removed afterward. Release packaging has a separate deny-list
check for the presentation manifest, script path, and runtime profile.

## Outputs

- `media/hero.png` — a bottom-centre crop exported at exactly **1300×372**
- `media/presentation/*.png` — full-size feature slides at the configured
  framebuffer resolution

Files are staged in an isolated runtime directory and published only after the
complete deck succeeds. A failed run keeps its runtime directory and logs for
diagnosis without replacing the current media.

## Configuration

The Linux capture profile is in `config.json` under `presentation.linux`:

- `baseConfig` points to the normal OpenMW configuration. Its data paths remain
  available, but the capture's checked-in content list replaces its active
  plugin list.
- `save` is the exact save loaded for the presentation.
- `contentList` points to the ordered content profile used by that save.
- `outputDir` is the repository-relative export destination.
- `captureWidth` and `captureHeight` control OpenMW's capture framebuffer.

When the presentation save's mod list changes, update
`dev-content/presentation/content-list.txt` to the exact ordered `content=`
entries that can load it without prompts. The capture manifest is appended by
the runner and must not be added to that file.

The slide copy, live example slot numbers, and option groups live in
`dev-content/scripts/voshondsQuickSelectPresentation/slides.lua`. Feature
examples reuse the production hotbar icon renderer against the loaded save, so
counts, charges, selected state, and equipment markers stay representative of
the current build. The hero artboard is intentionally fixed at 1300×372 while
feature slides use the full framebuffer.

The black-to-transparent backdrop is a TGA texture generated into the temporary
development mod directory for each capture. It never lives in the production
source tree or release archive, and the runner removes it when OpenMW exits.
The slide overlay redraws the visible hotbars above that texture with the same
production snapshot and icon renderer, preventing the fade from changing icon
brightness.

## Running

Requirements:

- OpenMW Flatpak
- Gamescope (provides a deterministic nested framebuffer)
- `jq`
- ImageMagick (`magick` and `identify`)
- `ydotool` with its daemon running
- `wmctrl` is optional but improves window focusing

Validate the profile without launching OpenMW:

```bash
./dev.sh capture --dry-run
```

Capture the complete deck:

```bash
./dev.sh capture
```

Open the persistent capture profile when thresholds, colours, text styles, or
other in-game settings need adjustment:

```bash
./dev.sh capture --setup
```

This launches the configured save and exact content list without the
presentation deck. Change the settings under **Options → Scripts**, then exit
OpenMW. The profile is stored under the ignored `.presentation-profile/`
directory. Future captures copy its player settings and setup save into each
isolated run; release builds never include the profile.

Useful overrides:

```bash
./dev.sh capture --save /absolute/path/Presentation.omwsave
./dev.sh capture --content-list dev-content/presentation/other-content-list.txt
./dev.sh capture --timeout 180
./dev.sh capture --keep-runtime
```

The runner stops an existing OpenMW instance, deploys the current production
mod source, launches the save with `--skip-menu`, and drives the deck after each
slide reports that it is ready. Screenshots come from OpenMW itself; ImageMagick
is used only to crop and verify the hero.
