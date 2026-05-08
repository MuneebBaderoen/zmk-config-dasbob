# AGENTS.md

## Keymap Formatting Rules

When formatting ZMK keymap layer grids:

- Align bindings by key position, not by token length.
- Start each binding in a fixed column so `&...` bindings and macro-style bindings like `LALT_T(...)`, `RMOD(...)`, and similar wrappers line up vertically.
- Keep the `/**/` marker as the fixed center split between the left and right halves of the keyboard.
- Preserve a consistent per-layer shape: three main rows plus one thumb row.
- Indent the thumb row so its three bindings align under the center three bindings of the row above.
- Pad with spaces as needed so the visual layout reflects the physical keyboard matrix.
- Prefer formatting that makes layers comparable position-by-position at a glance.
