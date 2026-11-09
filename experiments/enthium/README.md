# Enthium with Nordrassil W/B positions

These experiments use the repository's current `Base` and `AltOne` mappings,
not a canonical published layout. The active keymap is unchanged.

## Candidates

`wb.patch` swaps W/F and B/J in AltOne. `wb-cs.patch` makes those same
swaps plus C/S. Apply only one patch to the current keymap, not both.
Both preserve the behaviors attached to each physical position, including
layer taps, thumbs, combos, and shortcuts.

The C/S variant is:

```text
J Y O U -  |  Q L D P F
S I A E .  |  K H T N C
X ' / , :  |  B M G W V
    Space  |  R
```

The thumb line shows only the Space/R tap outputs; all other thumb bindings
remain unchanged. The W/B-only variant retains C at left home pinky and S
at right home pinky.

## Measurements

| Metric | Base | AltOne | W/B fixed | W/B fixed + C/S |
|---|---:|---:|---:|---:|
| Same-finger bigrams | 1.022% | 0.629% | 0.931% | 0.886% |
| Same-finger skipgrams | 6.759% | 5.496% | 5.643% | 5.566% |
| Redirects | 1.379% | 1.905% | 1.688% | 1.765% |
| Combined pinky load | 11.211% | 14.496% | 13.480% | 13.480% |
| Right-hand letter load | 45.424% | 54.682% | 56.041% | 52.623% |

The W/B swaps introduce same-finger BL, MB, and WN; they remove NF, WS,
and SW. Examples worth testing include `able`, `number`, and `down`.
F moves to the upper right pinky and J to the upper left pinky.

C/S fixes ICE by alternating left/right/left, while retaining home-row C.
It also removes redirects in ICA and ACE, but introduces them in IES,
ASE, OUS, OSE, and others. Words such as `stories`, `case`, `famous`,
and `those` are useful counterexamples to test alongside `ice`, `nice`,
`price`, and `service`. It moves the frequent S to the left pinky,
so the unchanged combined pinky load hides a redistribution between hands.
For Vim, C changes hands: test `cw`, `ciw`, and `ci(` as well as W/B.

The script also enumerates single C swaps after fixing W/B, keeping the
R thumb and W/B positions fixed. Candidates must type ICE with three
different fingers and without a redirect. Full results are in `results.json`.
This is a limited neighborhood search, not global optimization.

## Method and limits

This is an independent, small analyzer using Oxeylyzer's English frequency
data (internally named `shai`). It does not run Oxeylyzer's scoring engine.
Source commit: `d015a1692d3768e88e23ae4e9ae271a0f06807dc`.

Data URL:
https://raw.githubusercontent.com/o-x-e-y/oxeylyzer/d015a1692d3768e88e23ae4e9ae271a0f06807dc/oxeylyzer-core/static/language_data/english.json

Download that file, then run from the repository root:

```sh
python3 experiments/enthium/analyze.py /path/to/english.json
git apply --check experiments/enthium/wb-cs.patch
```

Each frequency table is filtered to the 25 base-layer letters, then
renormalized independently. Z, spaces, punctuation, shift, and layer
actions are excluded. Filtering removes whole n-grams; it does not join
characters across removed symbols. These percentages are not directly
comparable with other analyzers using different denominators.

Standard column fingering is assumed: each index finger owns two columns,
and R/T on the thumbs are assigned separate thumb fingers. Same-finger
metrics exclude repeated identical letters; skipgrams use one intervening
character. Redirects require three distinct non-thumb fingers on one hand
with a direction reversal. Repeated-finger patterns are not redirects here.

No physical distance, column stagger, roll preference, finger strength,
tap/hold timing, or personal Vim command frequencies are scored. The corpus
is generic English, not the user's writing or code. Lower scores do not
predict fewer typos. Actual typing trials are still needed.

Both patches passed `git apply --check` against the current working file.
The analysis script passed its assertion-based self-checks. No firmware
build or flashing was performed.
