"""Compare this repository's letter layouts using an Oxeylyzer corpus JSON.

Usage: python3 experiments/enthium/analyze.py /path/to/english.json
This is a small independent analyzer, not Oxeylyzer's scoring engine.
"""
import json
import string
import sys

# Z is reached through another layer in this keymap; exclude it rather than
# pretending its layer access has the cost of a base-layer key.
ALPHA = set(string.ascii_lowercase) - {"z"}
# Standard column fingering; inner columns share the index finger.
FINGERS = [0, 1, 2, 3, 3, 6, 6, 7, 8, 9] * 3 + [4, 5]
BASE = "qyou-jgnfkhiea.pdrslx'/,:bcmwv" + "t "
ENTHIUM = "byou-qldpwciae.khtnsx'/,:jmgfv" + " r"


def swap(layout, a, b):
    return layout.translate(str.maketrans({a: b, b: a}))


def finger_map(layout):
    assert len(layout) == 32 and len(set(layout)) == 32
    assert ALPHA <= set(layout)
    return dict(zip(layout, FINGERS))


def same_finger(pair, fingers):
    return pair[0] != pair[1] and fingers[pair[0]] == fingers[pair[1]]


def redirect(triple, fingers):
    f = [fingers[c] for c in triple]
    return (len(set(f)) == 3 and not ({4, 5} & set(f))
            and (all(i < 4 for i in f) or all(i > 5 for i in f))
            and (f[1] - f[0]) * (f[2] - f[1]) < 0)


def percent(data, predicate):
    return 100 * sum(v for k, v in data.items() if predicate(k)) / sum(data.values())


def metrics(layout, corpus):
    fingers = finger_map(layout)
    return {
        "same_finger_bigrams": percent(corpus["bigrams"], lambda k: same_finger(k, fingers)),
        "same_finger_skipgrams": percent(corpus["skipgrams"], lambda k: same_finger(k, fingers)),
        "redirects": percent(corpus["trigrams"], lambda k: redirect(k, fingers)),
        "pinky_load": percent(corpus["chars"], lambda k: fingers[k] in (0, 9)),
        "right_hand_load": percent(corpus["chars"], lambda k: fingers[k] >= 5),
        "ice_fingers": [fingers[k] for k in "ice"],
    }


def self_check():
    f = finger_map(ENTHIUM)
    assert redirect("ice", f)
    assert not redirect("you", f)
    assert same_finger("ci", finger_map(swap(ENTHIUM, "c", "y")))
    assert not same_finger("cc", f)
    assert same_finger("cs", finger_map(swap(ENTHIUM, "c", "s"))) is False
    assert percent({"a": 1, "b": 3}, lambda k: k == "a") == 25
    assert swap(swap(ENTHIUM, "b", "j"), "b", "j") == ENTHIUM


def main():
    self_check()
    raw = json.load(open(sys.argv[1]))
    corpus = {kind: {k: v for k, v in raw[kind].items() if set(k) <= ALPHA}
              for kind in ("chars", "bigrams", "skipgrams", "trigrams")}
    wb = swap(swap(ENTHIUM, "w", "f"), "b", "j")
    assert wb.index("w") == BASE.index("w") and wb.index("b") == BASE.index("b")
    layouts = {"base": BASE, "enthium": ENTHIUM, "enthium_wb": wb}
    for c in sorted(ALPHA - set("cwbr")):
        candidate = swap(wb, "c", c)
        f = finger_map(candidate)
        # Require three different fingers and no reversal for ICE.
        if len({f[k] for k in "ice"}) == 3 and not redirect("ice", f):
            layouts["enthium_wb_c_" + c] = candidate
    result = {name: {"layout": layout, **metrics(layout, corpus)} for name, layout in layouts.items()}
    before, after = finger_map(ENTHIUM), finger_map(wb)
    for label, predicate in (("sfbs", same_finger), ("redirects", redirect)):
        data = corpus["bigrams" if label == "sfbs" else "trigrams"]
        result["wb_" + label + "_changes"] = {
            direction: sorted([(k, 100 * v / sum(data.values())) for k, v in data.items()
                               if predicate(k, after) - predicate(k, before) == sign],
                              key=lambda pair: -pair[1])[:15]
            for direction, sign in (("added", 1), ("removed", -1))}
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
