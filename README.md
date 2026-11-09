# Dasbob ZMK configuration

## Render the keymap

Install [uv](https://docs.astral.sh/uv/getting-started/installation/), then run:

```sh
make render-keymap
```

Open `zmk-out/dasbob.svg` in a browser. The command runs a pinned version of
[keymap-drawer](https://github.com/caksoylar/keymap-drawer) and downloads its
Python dependencies on first use. No firmware build or Docker is needed.

Edit `DRAW_LAYERS` in `keymap-drawer/render.mk` to choose the layers to display,
in display order. Use the exact node names from `zmk-config/dasbob.keymap`.
Set `HIDE_LAYERS` in the same file to exclude names from that list. Hiding takes
precedence over `DRAW_LAYERS`; clear `HIDE_LAYERS` to show the whole list.
This configuration affects rendering only; it does not change the firmware,
layer numbering, or bindings. The initial selection hides `Num`
and the internal `BeepMute` layer. Hold either the left middle-finger or index-finger
home-row key on `Base` or `AltOne` to activate `Num`; tapping keeps the letter.
`Nav`, defined immediately after it, provides navigation and shortcuts.
`AltOne` is also hidden, along with its activation combo.
Combo visibility is configured by node name under `parse_config.zmk_combos`
in `keymap-drawer/config.yaml` using `hidden: true`.

For a one-off selection:

```sh
make render-keymap DRAW_LAYERS='Base Sym Nav'
```

To override the hidden layers for one render:

```sh
make render-keymap HIDE_LAYERS='Num BeepMute'
```

Hidden layers can still appear as legends on keys or combos that activate them.
Names in `HIDE_LAYERS` that are not in `DRAW_LAYERS` have no effect.

All layers are parsed before selecting which to draw, so layer references keep
their original names. Empty visible selections and unknown visible layer names
fail the command.
The generated `zmk-out/dasbob.yaml` includes all layers for inspection; do not
edit it, since the next render overwrites it. Generated files are git-ignored.

The drawing uses a schematic split 3×5+3 layout in keymap order, not the exact
Dasbob column stagger. Tap legends appear in the center, hold legends below,
and shifted mod-morph legends above. Combos appear in separate diagrams.
Adjust custom behavior legends and drawing settings in `keymap-drawer/config.yaml`.
